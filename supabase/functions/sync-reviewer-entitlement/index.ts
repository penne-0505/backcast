import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

type JsonRecord = Record<string, unknown>;

type SyncReviewerEntitlementDependencies = {
  createUserClient?: (authorization: string) => SupabaseClient;
  createAdminClient?: () => SupabaseClient;
  env?: Pick<typeof Deno.env, "get">;
  now?: () => Date;
};

const jsonHeaders = { "Content-Type": "application/json" };
const paidStatuses = new Set([
  "active",
  "trial",
  "cancelled_but_active",
  "billing_issue",
  "grace_period",
]);

if (import.meta.main) {
  Deno.serve((request) => handleSyncReviewerEntitlement(request));
}

export async function handleSyncReviewerEntitlement(
  request: Request,
  dependencies: SyncReviewerEntitlementDependencies = {},
) {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  const jwt = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : null;
  if (!authorization || !jwt) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const userClient = dependencies.createUserClient?.(authorization) ??
    createUserClient(authorization, dependencies.env);
  const { data: userData, error: userError } = await userClient.auth.getUser(
    jwt,
  );
  if (userError || !userData.user) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const userId = userData.user.id;
  const email = normalizeEmail(userData.user.email);
  if (!email) {
    return jsonResponse({ ok: true, applied: false, reason: "missing_email" });
  }

  const admin = dependencies.createAdminClient?.() ??
    createAdminClient(dependencies.env);
  const now = dependencies.now?.() ?? new Date();

  const { data: allowlist, error: allowlistError } = await admin
    .from("reviewer_entitlement_allowlist")
    .select("email,entitlement_id,expires_at,disabled_at")
    .eq("email", email)
    .maybeSingle();
  if (allowlistError) {
    console.error("reviewer_allowlist_read_failed", {
      user_id: userId,
      code: allowlistError.code,
      message: allowlistError.message,
    });
    return jsonResponse({ error: "allowlist_read_failed" }, 500);
  }

  const { data: existing, error: existingError } = await admin
    .from("user_pro_entitlements")
    .select("is_pro,status,expires_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (existingError) {
    console.error("reviewer_entitlement_read_failed", {
      user_id: userId,
      code: existingError.code,
      message: existingError.message,
    });
    return jsonResponse({ error: "entitlement_read_failed" }, 500);
  }

  if (!isAllowlistActive(allowlist, now)) {
    const cleared = await clearTemporaryEntitlement(
      admin,
      userId,
      existing,
      now,
    );
    if (cleared.error) {
      return jsonResponse({ error: "temporary_entitlement_clear_failed" }, 500);
    }
    return jsonResponse({
      ok: true,
      applied: false,
      cleared: cleared.cleared,
      reason: allowlist ? "allowlist_inactive" : "not_allowlisted",
    });
  }

  if (hasPaidEntitlement(existing)) {
    return jsonResponse({
      ok: true,
      applied: false,
      reason: "paid_entitlement_preserved",
    });
  }

  const activeAllowlist = allowlist as JsonRecord;
  const expiresAt = readString(activeAllowlist, "expires_at");
  const upsertResult = await admin.from("user_pro_entitlements").upsert({
    user_id: userId,
    is_pro: true,
    status: "temporary",
    revenuecat_app_user_id: userId,
    product_id: readString(activeAllowlist, "entitlement_id") ??
      "reviewer_temporary",
    expires_at: expiresAt,
    last_synced_at: now.toISOString(),
  }, { onConflict: "user_id" });

  if (upsertResult.error) {
    console.error("reviewer_entitlement_upsert_failed", {
      user_id: userId,
      code: upsertResult.error.code,
      message: upsertResult.error.message,
    });
    return jsonResponse({ error: "temporary_entitlement_upsert_failed" }, 500);
  }

  return jsonResponse({ ok: true, applied: true, expires_at: expiresAt });
}

async function clearTemporaryEntitlement(
  admin: SupabaseClient,
  userId: string,
  existing: JsonRecord | null,
  now: Date,
) {
  if (readString(existing ?? {}, "status") !== "temporary") {
    return { cleared: false, error: null };
  }

  const result = await admin.from("user_pro_entitlements").upsert({
    user_id: userId,
    is_pro: false,
    status: "inactive",
    product_id: null,
    period_type: null,
    purchased_at: null,
    expires_at: null,
    grace_period_expires_at: null,
    last_synced_at: now.toISOString(),
  }, { onConflict: "user_id" });

  if (result.error) {
    console.error("reviewer_entitlement_clear_failed", {
      user_id: userId,
      code: result.error.code,
      message: result.error.message,
    });
    return { cleared: false, error: result.error };
  }
  return { cleared: true, error: null };
}

function isAllowlistActive(allowlist: JsonRecord | null, now: Date) {
  if (!allowlist) return false;
  if (readString(allowlist, "disabled_at")) return false;
  const expiresAt = readString(allowlist, "expires_at");
  if (!expiresAt) return false;
  return new Date(expiresAt).getTime() > now.getTime();
}

function hasPaidEntitlement(existing: JsonRecord | null) {
  if (!existing) return false;
  if (readString(existing, "status") === "temporary") return false;
  return existing.is_pro === true &&
    paidStatuses.has(readString(existing, "status") ?? "");
}

function normalizeEmail(email: unknown) {
  return typeof email === "string" && email.trim().length > 0
    ? email.trim().toLowerCase()
    : null;
}

function createUserClient(
  authorization: string,
  env: Pick<typeof Deno.env, "get"> = Deno.env,
) {
  return createClient(
    mustGetEnv("SUPABASE_URL", env),
    getSupabasePublishableKey(env),
    {
      global: { headers: { Authorization: authorization } },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
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

function getSupabasePublishableKey(
  env: Pick<typeof Deno.env, "get"> = Deno.env,
) {
  const legacy = env.get("SUPABASE_ANON_KEY");
  if (legacy) return legacy;

  const keys = env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (!keys) throw new Error("Missing Supabase publishable key");

  const parsed = JSON.parse(keys) as Record<string, string>;
  const key = parsed.default ?? Object.values(parsed)[0];
  if (!key) throw new Error("Missing Supabase publishable key");
  return key;
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

function readString(record: JsonRecord, key: string) {
  const value = record[key];
  return typeof value === "string" && value.length > 0 ? value : null;
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
