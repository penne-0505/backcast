import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

type JsonRecord = Record<string, unknown>;

type UsageAnalyticsDependencies = {
  createAdminClient?: () => SupabaseClient;
  env?: Pick<typeof Deno.env, "get">;
  now?: () => Date;
};

const jsonHeaders = { "Content-Type": "application/json" };
const maxBatchSize = 50;
const maxBodyBytes = 64 * 1024;
const platforms = new Set([
  "android",
  "ios",
  "macos",
  "linux",
  "windows",
  "web",
  "unknown",
]);
const countBuckets = new Set(["0", "1", "2-3", "4-5", "6-10", "11+"]);
const eventCountBuckets = new Set(["1", "2-3", "4-5", "6-10", "11+"]);

const eventSchemas: Record<string, Record<string, Set<unknown> | "boolean">> = {
  app_opened: {
    launch_source: new Set(["cold_start", "resume"]),
    platform: platforms,
  },
  first_plan_created: { block_count_bucket: countBuckets },
  plan_created: {
    source: new Set(["initial_bootstrap", "timeline_list", "fallback"]),
    block_count_bucket: countBuckets,
  },
  plan_saved: {
    block_count_bucket: countBuckets,
    has_buffer: "boolean",
  },
  block_added: {
    block_type: new Set(["action", "actionPoint"]),
    block_count_bucket: countBuckets,
  },
  block_reordered: { block_count_bucket: countBuckets },
  template_created: { block_count_bucket: countBuckets },
  template_applied: { block_count_bucket: countBuckets },
  calendar_export_started: {
    event_count_bucket: eventCountBuckets,
    platform: platforms,
  },
  calendar_export_completed: {
    event_count_bucket: eventCountBuckets,
    result: new Set([
      "success",
      "permission_denied",
      "no_writable_calendar",
      "invalid_payload",
      "unsupported_platform",
      "save_failed",
      "exception",
    ]),
  },
  text_share_completed: { block_count_bucket: countBuckets },
  image_share_completed: {
    block_count_bucket: countBuckets,
    result: new Set(["success", "failure"]),
  },
  paywall_viewed: {
    source: new Set([
      "templates",
      "timeline_count",
      "image_export",
      "action_buffer",
    ]),
  },
  purchase_started: { source: new Set(["paywall"]) },
  purchase_completed: {
    result: new Set(["pending", "cancelled", "failed", "restored"]),
  },
  account_deleted: { had_pro_cache: "boolean" },
};

if (import.meta.main) {
  Deno.serve((request) => handleUsageAnalytics(request));
}

export async function handleUsageAnalytics(
  request: Request,
  dependencies: UsageAnalyticsDependencies = {},
) {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maxBodyBytes) {
    return jsonResponse({ error: "payload_too_large" }, 413);
  }

  let body: JsonRecord;
  try {
    body = JSON.parse(rawBody) as JsonRecord;
  } catch (_) {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const validation = validateBatch(body);
  if (!validation.ok) {
    return jsonResponse({ error: validation.error }, 400);
  }

  const admin = dependencies.createAdminClient?.() ??
    createAdminClient(dependencies.env);
  const now = dependencies.now?.() ?? new Date();
  const batch = validation.batch;

  const { data: batchRow, error: batchError } = await admin
    .from("analytics_event_batches")
    .insert({
      install_id: batch.installId,
      app_version: batch.appVersion,
      platform: batch.platform,
      event_count: batch.events.length,
      received_at: now.toISOString(),
    })
    .select("id")
    .single();

  if (batchError || !batchRow) {
    console.error("analytics_batch_insert_failed", {
      code: batchError?.code,
      message: batchError?.message,
    });
    return jsonResponse({ error: "batch_insert_failed" }, 500);
  }

  const batchId = readString(batchRow as JsonRecord, "id");
  if (!batchId) {
    console.error("analytics_batch_insert_failed", {
      message: "missing_inserted_batch_id",
    });
    return jsonResponse({ error: "batch_insert_failed" }, 500);
  }

  const rows = batch.events.map((event) => ({
    batch_id: batchId,
    client_event_id: event.id,
    install_id: event.installId,
    session_id: event.sessionId,
    event_name: event.eventName,
    properties: event.properties,
    occurred_at: event.occurredAt,
    received_at: now.toISOString(),
  }));

  const insertResult = await insertEvents(admin, rows);
  if (!insertResult.ok) {
    await deleteBatch(admin, batchId);
    console.error("analytics_events_insert_failed", {
      code: insertResult.error.code,
      message: insertResult.error.message,
    });
    return jsonResponse({ error: "events_insert_failed" }, 500);
  }

  if (insertResult.insertedCount === 0) {
    await deleteBatch(admin, batchId);
  }

  return jsonResponse({
    ok: true,
    accepted: rows.length,
    duplicate: insertResult.duplicate,
  });
}

async function insertEvents(
  admin: SupabaseClient,
  rows: Record<string, unknown>[],
) {
  const { error } = await admin
    .from("analytics_events")
    .insert(rows);
  if (!error) {
    return {
      ok: true as const,
      insertedCount: rows.length,
      duplicate: false,
    };
  }
  if (error.code !== "23505") {
    return { ok: false as const, error };
  }

  let insertedCount = 0;
  for (const row of rows) {
    const { error: rowError } = await admin
      .from("analytics_events")
      .insert(row);
    if (!rowError) {
      insertedCount += 1;
      continue;
    }
    if (rowError.code === "23505") continue;
    return { ok: false as const, error: rowError };
  }

  return {
    ok: true as const,
    insertedCount,
    duplicate: true,
  };
}

async function deleteBatch(admin: SupabaseClient, batchId: string) {
  const { error } = await admin
    .from("analytics_event_batches")
    .delete()
    .eq("id", batchId);
  if (error) {
    console.error("analytics_batch_cleanup_failed", {
      code: error.code,
      message: error.message,
    });
  }
}

function validateBatch(body: JsonRecord) {
  const appVersion = readString(body, "app_version");
  const platform = readString(body, "platform");
  const events = body.events;
  if (!appVersion || appVersion.length > 64) {
    return invalid("invalid_app_version");
  }
  if (!platform || !platforms.has(platform)) return invalid("invalid_platform");
  if (!Array.isArray(events) || events.length === 0) {
    return invalid("invalid_events");
  }
  if (events.length > maxBatchSize) return invalid("batch_too_large");

  const normalizedEvents = [];
  for (const rawEvent of events) {
    if (!isRecord(rawEvent)) return invalid("invalid_event");
    const normalized = validateEvent(rawEvent);
    if (!normalized.ok) return invalid(normalized.error);
    normalizedEvents.push(normalized.event);
  }

  const installId = normalizedEvents[0].installId;
  if (normalizedEvents.some((event) => event.installId !== installId)) {
    return invalid("mixed_install_ids");
  }

  return {
    ok: true as const,
    batch: { appVersion, platform, installId, events: normalizedEvents },
  };
}

function validateEvent(raw: JsonRecord) {
  const id = readString(raw, "id");
  const eventName = readString(raw, "event_name");
  const occurredAt = readString(raw, "occurred_at");
  const sessionId = readString(raw, "session_id");
  const installId = readString(raw, "install_id");
  if (!isUuid(id)) return invalid("invalid_event_id");
  if (!eventName || !(eventName in eventSchemas)) {
    return invalid("unsupported_event_name");
  }
  if (!isUuid(sessionId)) return invalid("invalid_session_id");
  if (!isUuid(installId)) return invalid("invalid_install_id");
  if (!occurredAt || Number.isNaN(new Date(occurredAt).getTime())) {
    return invalid("invalid_occurred_at");
  }
  if (!isRecord(raw.properties)) return invalid("invalid_properties");

  const schema = eventSchemas[eventName];
  const properties: JsonRecord = {};
  for (const [key, value] of Object.entries(raw.properties)) {
    const rule = schema[key];
    if (!rule) return invalid("unsupported_property");
    if (rule === "boolean") {
      if (typeof value !== "boolean") return invalid("invalid_property_value");
      properties[key] = value;
    } else {
      if (typeof value !== "string" || !rule.has(value)) {
        return invalid("invalid_property_value");
      }
      properties[key] = value;
    }
  }

  return {
    ok: true as const,
    event: { id, eventName, properties, occurredAt, sessionId, installId },
  };
}

function createAdminClient(env: Pick<typeof Deno.env, "get"> = Deno.env) {
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

function mustGetEnv(key: string, env: Pick<typeof Deno.env, "get"> = Deno.env) {
  const value = env.get(key);
  if (!value) throw new Error(`Missing required environment variable: ${key}`);
  return value;
}

function readString(record: JsonRecord, key: string) {
  const value = record[key];
  return typeof value === "string" && value.length > 0 ? value : null;
}

function isRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isUuid(value: string | null) {
  return value !== null &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function invalid(error: string) {
  return { ok: false as const, error };
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}
