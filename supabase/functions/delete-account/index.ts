import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
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

  const userClient = createClient(
    mustGetEnv("SUPABASE_URL"),
    getSupabasePublishableKey(),
    {
      global: { headers: { Authorization: authorization } },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );

  const { data: userData, error: userError } = await userClient.auth.getUser(
    jwt,
  );
  if (userError || !userData.user) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const admin = createClient(
    mustGetEnv("SUPABASE_URL"),
    getSupabaseSecretKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    userData.user.id,
  );
  if (deleteError) {
    console.error("delete_account_failed", {
      user_id: userData.user.id,
      message: deleteError.message,
      status: deleteError.status,
    });
    return jsonResponse({ error: "delete_account_failed" }, 500);
  }

  return jsonResponse({ ok: true });
});

function getSupabasePublishableKey() {
  const legacy = Deno.env.get("SUPABASE_ANON_KEY");
  if (legacy) return legacy;

  const keys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (!keys) throw new Error("Missing Supabase publishable key");

  const parsed = JSON.parse(keys) as Record<string, string>;
  const key = parsed.default ?? Object.values(parsed)[0];
  if (!key) throw new Error("Missing Supabase publishable key");
  return key;
}

function getSupabaseSecretKey() {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;

  const secrets = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!secrets) throw new Error("Missing Supabase secret key");

  const parsed = JSON.parse(secrets) as Record<string, string>;
  const key = parsed.default ?? Object.values(parsed)[0];
  if (!key) throw new Error("Missing Supabase secret key");
  return key;
}

function mustGetEnv(key: string) {
  const value = Deno.env.get(key);
  if (!value) throw new Error(`Missing required environment variable: ${key}`);
  return value;
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}
