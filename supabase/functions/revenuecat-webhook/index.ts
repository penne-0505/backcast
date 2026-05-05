import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

type JsonRecord = Record<string, unknown>;

type RevenueCatWebhookBody = {
  api_version?: string;
  event?: JsonRecord;
};

type EntitlementSnapshot = {
  isPro: boolean;
  status: string;
  productId: string | null;
  store: string | null;
  periodType: string | null;
  purchasedAt: string | null;
  expiresAt: string | null;
  gracePeriodExpiresAt: string | null;
};

const jsonHeaders = { "Content-Type": "application/json" };

type RevenueCatWebhookDependencies = {
  createAdminClient?: () => SupabaseClient;
  env?: Pick<typeof Deno.env, "get">;
  fetch?: typeof fetch;
  now?: () => Date;
};

if (import.meta.main) {
  Deno.serve((request) => handleRevenueCatWebhook(request));
}

export async function handleRevenueCatWebhook(
  request: Request,
  dependencies: RevenueCatWebhookDependencies = {},
) {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const env = dependencies.env ?? Deno.env;
  const expectedAuth = mustGetEnv("REVENUECAT_WEBHOOK_AUTHORIZATION", env);
  if (request.headers.get("Authorization") !== expectedAuth) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let body: RevenueCatWebhookBody;
  try {
    body = await request.json();
  } catch (_error) {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const event = isRecord(body.event) ? body.event : null;
  if (!event) return jsonResponse({ error: "missing_event" }, 400);

  const eventId = readString(event, "id");
  const eventType = readString(event, "type");
  const eventTimestampMs = readNumber(event, "event_timestamp_ms");
  if (!eventId || !eventType || eventTimestampMs == null) {
    return jsonResponse({ error: "invalid_event" }, 400);
  }

  const supabase = dependencies.createAdminClient?.() ??
    createAdminClientWithEnv(env);
  const userId = await resolveUserId(supabase, event);
  if (!userId) {
    console.warn("revenuecat_webhook_unresolved_user", {
      event_id: eventId,
      event_type: eventType,
      reason: "no_candidate_auth_user",
    });
    return jsonResponse({ ok: true, skipped: "unresolved_user" });
  }

  const eventAt = new Date(eventTimestampMs).toISOString();
  let snapshot: EntitlementSnapshot;
  try {
    snapshot = await fetchSubscriberEntitlement(userId, event, dependencies);
  } catch (error) {
    console.error("revenuecat_subscriber_sync_failed", {
      event_id: eventId,
      event_type: eventType,
      user_id: userId,
      message: error instanceof Error ? error.message : String(error),
    });
    return jsonResponse({ error: "subscriber_sync_failed" }, 502);
  }

  const relatedAppUserIds = readRelatedAppUserIds(event);
  const entitlementIds = readStringArray(event, "entitlement_ids");

  const eventRow = {
    user_id: userId,
    revenuecat_event_id: eventId,
    revenuecat_event_type: eventType,
    revenuecat_app_user_id: readString(event, "app_user_id"),
    original_app_user_id: readString(event, "original_app_user_id"),
    related_app_user_ids: relatedAppUserIds.length > 0
      ? relatedAppUserIds
      : null,
    pro_after: snapshot.isPro,
    status_after: snapshot.status,
    environment: readString(event, "environment"),
    store: snapshot.store ?? readString(event, "store"),
    product_id: snapshot.productId ?? readString(event, "product_id"),
    entitlement_ids: entitlementIds.length > 0 ? entitlementIds : null,
    transaction_id: readString(event, "transaction_id"),
    original_transaction_id: readString(event, "original_transaction_id"),
    period_type: snapshot.periodType ?? readString(event, "period_type"),
    purchased_at: snapshot.purchasedAt ??
      fromMillis(readNumber(event, "purchased_at_ms")),
    expires_at: snapshot.expiresAt ??
      fromMillis(readNumber(event, "expiration_at_ms")),
    grace_period_expires_at: snapshot.gracePeriodExpiresAt ??
      fromMillis(readNumber(event, "grace_period_expiration_at_ms")),
    event_at: eventAt,
  };

  const insertResult = await supabase.from("pro_entitlement_events").insert(
    eventRow,
  );
  if (insertResult.error && insertResult.error.code !== "23505") {
    console.error("revenuecat_event_insert_failed", {
      event_id: eventId,
      user_id: userId,
      code: insertResult.error.code,
      message: insertResult.error.message,
    });
    return jsonResponse({ error: "event_insert_failed" }, 500);
  }

  const { data: existing, error: existingError } = await supabase
    .from("user_pro_entitlements")
    .select("last_event_at,last_revenuecat_event_id,last_revenuecat_event_type")
    .eq("user_id", userId)
    .maybeSingle();
  if (existingError) {
    console.error("pro_entitlement_existing_read_failed", {
      event_id: eventId,
      user_id: userId,
      code: existingError.code,
      message: existingError.message,
    });
    return jsonResponse({ error: "current_state_read_failed" }, 500);
  }

  const existingLastEventAt = readString(existing ?? {}, "last_event_at");
  const incomingIsNewest = existingLastEventAt == null ||
    new Date(eventAt).getTime() >= new Date(existingLastEventAt).getTime();
  const lastEventAt = incomingIsNewest ? eventAt : existingLastEventAt;

  const upsertResult = await supabase.from("user_pro_entitlements").upsert({
    user_id: userId,
    is_pro: snapshot.isPro,
    status: snapshot.status,
    revenuecat_app_user_id: userId,
    environment: readString(event, "environment"),
    store: snapshot.store ?? readString(event, "store"),
    product_id: snapshot.productId,
    period_type: snapshot.periodType,
    purchased_at: snapshot.purchasedAt,
    expires_at: snapshot.expiresAt,
    grace_period_expires_at: snapshot.gracePeriodExpiresAt,
    last_revenuecat_event_id: incomingIsNewest
      ? eventId
      : readString(existing ?? {}, "last_revenuecat_event_id"),
    last_revenuecat_event_type: incomingIsNewest
      ? eventType
      : readString(existing ?? {}, "last_revenuecat_event_type"),
    last_event_at: lastEventAt,
    last_synced_at: (dependencies.now?.() ?? new Date()).toISOString(),
  }, { onConflict: "user_id" });

  if (upsertResult.error) {
    console.error("pro_entitlement_upsert_failed", {
      event_id: eventId,
      user_id: userId,
      code: upsertResult.error.code,
      message: upsertResult.error.message,
    });
    return jsonResponse({ error: "current_state_upsert_failed" }, 500);
  }

  return jsonResponse({
    ok: true,
    duplicate_event: insertResult.error?.code === "23505",
  });
}

async function resolveUserId(
  supabase: SupabaseClient,
  event: JsonRecord,
): Promise<string | null> {
  const candidates = [
    readString(event, "app_user_id"),
    readString(event, "original_app_user_id"),
    ...readStringArray(event, "aliases"),
    ...readStringArray(event, "transferred_to"),
    ...readStringArray(event, "transferred_from"),
  ].filter((candidate): candidate is string => isUuid(candidate));

  for (const candidate of new Set(candidates)) {
    const { data, error } = await supabase.auth.admin.getUserById(candidate);
    if (!error && data.user) return candidate;
  }

  return null;
}

async function fetchSubscriberEntitlement(
  userId: string,
  event: JsonRecord,
  dependencies: RevenueCatWebhookDependencies = {},
): Promise<EntitlementSnapshot> {
  const env = dependencies.env ?? Deno.env;
  const apiKey = mustGetEnv("REVENUECAT_SECRET_API_KEY", env);
  const entitlementId = mustGetEnv("REVENUECAT_PRO_ENTITLEMENT_ID", env);
  const fetcher = dependencies.fetch ?? fetch;
  const response = await fetcher(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
    { headers: { Authorization: `Bearer ${apiKey}` } },
  );

  if (!response.ok) {
    throw new Error(`RevenueCat subscriber API returned ${response.status}`);
  }

  const payload = await response.json();
  const subscriber = isRecord(payload.subscriber)
    ? payload.subscriber
    : isRecord(payload.value) && isRecord(payload.value.subscriber)
    ? payload.value.subscriber
    : null;
  if (!subscriber) throw new Error("RevenueCat subscriber payload missing");

  const entitlements = isRecord(subscriber.entitlements)
    ? subscriber.entitlements
    : {};
  const entitlement = isRecord(entitlements[entitlementId])
    ? entitlements[entitlementId] as JsonRecord
    : null;

  if (!entitlement) {
    return inactiveSnapshot();
  }

  const expiresAt = readString(entitlement, "expires_date");
  const isActive = expiresAt == null ||
    new Date(expiresAt).getTime() > Date.now();
  if (!isActive) return inactiveSnapshot({ expiresAt });

  const productId = readString(entitlement, "product_identifier");
  const subscription = findSubscription(subscriber, productId);
  const gracePeriodExpiresAt =
    readString(entitlement, "grace_period_expires_date") ??
      readString(subscription ?? {}, "grace_period_expires_date");
  const billingIssueAt = readString(
    subscription ?? {},
    "billing_issues_detected_at",
  );
  const unsubscribeAt = readString(
    subscription ?? {},
    "unsubscribe_detected_at",
  );
  const periodType = readString(entitlement, "period_type") ??
    readString(subscription ?? {}, "period_type") ??
    readString(event, "period_type");

  return {
    isPro: true,
    status: deriveStatus({
      periodType,
      expiresAt,
      gracePeriodExpiresAt,
      billingIssueAt,
      unsubscribeAt,
      eventType: readString(event, "type"),
    }),
    productId,
    store: readString(subscription ?? {}, "store") ??
      readString(event, "store"),
    periodType,
    purchasedAt: readString(entitlement, "purchase_date") ??
      readString(subscription ?? {}, "purchase_date"),
    expiresAt,
    gracePeriodExpiresAt,
  };
}

function deriveStatus(input: {
  periodType: string | null;
  expiresAt: string | null;
  gracePeriodExpiresAt: string | null;
  billingIssueAt: string | null;
  unsubscribeAt: string | null;
  eventType: string | null;
}): string {
  if (input.eventType === "TEMPORARY_ENTITLEMENT_GRANT") return "temporary";
  if (
    input.gracePeriodExpiresAt &&
    new Date(input.gracePeriodExpiresAt).getTime() > Date.now()
  ) {
    return "grace_period";
  }
  if (input.billingIssueAt) return "billing_issue";
  if (input.unsubscribeAt) return "cancelled_but_active";
  if (input.periodType?.toUpperCase() === "TRIAL") return "trial";
  return "active";
}

function findSubscription(
  subscriber: JsonRecord,
  productId: string | null,
): JsonRecord | null {
  if (!productId || !isRecord(subscriber.subscriptions)) return null;
  const subscription = subscriber.subscriptions[productId];
  return isRecord(subscription) ? subscription : null;
}

function inactiveSnapshot(overrides: Partial<EntitlementSnapshot> = {}) {
  return {
    isPro: false,
    status: "inactive",
    productId: null,
    store: null,
    periodType: null,
    purchasedAt: null,
    expiresAt: null,
    gracePeriodExpiresAt: null,
    ...overrides,
  };
}

function createAdminClient() {
  return createAdminClientWithEnv(Deno.env);
}

function createAdminClientWithEnv(env: Pick<typeof Deno.env, "get">) {
  return createClient(
    mustGetEnv("SUPABASE_URL", env),
    getSupabaseSecretKey(env),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

function getSupabaseSecretKey(env: Pick<typeof Deno.env, "get"> = Deno.env) {
  const legacy = env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;

  const secrets = env.get("SUPABASE_SECRET_KEYS");
  if (!secrets) throw new Error("Missing Supabase secret key");

  const parsed = JSON.parse(secrets) as Record<string, string>;
  const key = parsed.default ?? Object.values(parsed)[0];
  if (!key) throw new Error("Missing Supabase secret key");
  return key;
}

function readRelatedAppUserIds(event: JsonRecord) {
  return [
    ...readStringArray(event, "aliases"),
    ...readStringArray(event, "transferred_from"),
    ...readStringArray(event, "transferred_to"),
  ].filter((value, index, values) => values.indexOf(value) === index);
}

function readString(record: JsonRecord, key: string) {
  const value = record[key];
  return typeof value === "string" && value.length > 0 ? value : null;
}

function readNumber(record: JsonRecord, key: string) {
  const value = record[key];
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function readStringArray(record: JsonRecord, key: string) {
  const value = record[key];
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function fromMillis(value: number | null) {
  return value == null ? null : new Date(value).toISOString();
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isUuid(value: string | null): value is string {
  return value != null &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function mustGetEnv(key: string, env: Pick<typeof Deno.env, "get"> = Deno.env) {
  const value = env.get(key);
  if (!value) throw new Error(`Missing required environment variable: ${key}`);
  return value;
}

function jsonResponse(body: JsonRecord, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}
