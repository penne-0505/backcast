import { handleRevenueCatWebhook } from "./index.ts";

Deno.test("duplicate event still refreshes the current entitlement state", async () => {
  const supabase = new FakeSupabase({
    insertError: { code: "23505", message: "duplicate key value" },
  });

  const response = await handleRevenueCatWebhook(
    webhookRequest(baseEvent({ id: "event-duplicate" })),
    testDependencies({ supabase }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.duplicate_event, true);
  assertEquals(supabase.insertedEvents.length, 1);
  assertEquals(supabase.upsertedEntitlements.length, 1);
  assertEquals(supabase.upsertedEntitlements[0].is_pro, true);
});

Deno.test("unresolved RevenueCat users are acknowledged without database writes", async () => {
  const supabase = new FakeSupabase({ knownUsers: new Set() });

  const response = await handleRevenueCatWebhook(
    webhookRequest(baseEvent({ id: "event-unresolved" })),
    testDependencies({ supabase }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.skipped, "unresolved_user");
  assertEquals(supabase.insertedEvents.length, 0);
  assertEquals(supabase.upsertedEntitlements.length, 0);
});

Deno.test("RevenueCat API failures do not persist partial webhook state", async () => {
  const supabase = new FakeSupabase();

  const response = await handleRevenueCatWebhook(
    webhookRequest(baseEvent({ id: "event-api-failure" })),
    testDependencies({
      supabase,
      fetch: async () => new Response("unavailable", { status: 503 }),
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 502);
  assertEquals(body.error, "subscriber_sync_failed");
  assertEquals(supabase.insertedEvents.length, 0);
  assertEquals(supabase.upsertedEntitlements.length, 0);
});

Deno.test("out-of-order events keep the newest RevenueCat event metadata", async () => {
  const supabase = new FakeSupabase({
    existingEntitlement: {
      last_event_at: "2026-05-10T12:00:00.000Z",
      last_revenuecat_event_id: "event-newer",
      last_revenuecat_event_type: "RENEWAL",
    },
  });

  const response = await handleRevenueCatWebhook(
    webhookRequest(
      baseEvent({
        id: "event-older",
        type: "INITIAL_PURCHASE",
        event_timestamp_ms: Date.parse("2026-05-10T10:00:00.000Z"),
      }),
    ),
    testDependencies({ supabase }),
  );

  assertEquals(response.status, 200);
  assertEquals(supabase.upsertedEntitlements.length, 1);
  assertEquals(
    supabase.upsertedEntitlements[0].last_revenuecat_event_id,
    "event-newer",
  );
  assertEquals(
    supabase.upsertedEntitlements[0].last_revenuecat_event_type,
    "RENEWAL",
  );
  assertEquals(
    supabase.upsertedEntitlements[0].last_event_at,
    "2026-05-10T12:00:00.000Z",
  );
});

const userId = "11111111-1111-4111-8111-111111111111";

function testDependencies(options: {
  supabase: FakeSupabase;
  fetch?: typeof fetch;
}) {
  return {
    createAdminClient: () => options.supabase as never,
    env: {
      get(key: string) {
        return {
          REVENUECAT_WEBHOOK_AUTHORIZATION: "Bearer webhook-secret",
          REVENUECAT_SECRET_API_KEY: "rc-secret",
          REVENUECAT_PRO_ENTITLEMENT_ID: "pro",
        }[key];
      },
    },
    fetch: options.fetch ?? subscriberFetch(),
    now: () => new Date("2026-05-10T13:00:00.000Z"),
  };
}

function webhookRequest(event: Record<string, unknown>) {
  return new Request("http://localhost/revenuecat-webhook", {
    method: "POST",
    headers: {
      Authorization: "Bearer webhook-secret",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ api_version: "1.0", event }),
  });
}

function baseEvent(overrides: Record<string, unknown> = {}) {
  return {
    id: "event-1",
    type: "INITIAL_PURCHASE",
    app_user_id: userId,
    event_timestamp_ms: Date.parse("2026-05-10T11:00:00.000Z"),
    environment: "SANDBOX",
    store: "PLAY_STORE",
    product_id: "medo_pro_monthly",
    entitlement_ids: ["pro"],
    ...overrides,
  };
}

function subscriberFetch(): typeof fetch {
  return async () =>
    new Response(
      JSON.stringify({
        subscriber: {
          entitlements: {
            pro: {
              expires_date: "2026-06-10T11:00:00Z",
              product_identifier: "medo_pro_monthly",
              purchase_date: "2026-05-10T11:00:00Z",
              period_type: "NORMAL",
            },
          },
          subscriptions: {
            medo_pro_monthly: {
              store: "PLAY_STORE",
              period_type: "NORMAL",
              purchase_date: "2026-05-10T11:00:00Z",
            },
          },
        },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
}

class FakeSupabase {
  constructor(
    private readonly options: {
      knownUsers?: Set<string>;
      insertError?: { code: string; message: string };
      existingEntitlement?: Record<string, unknown> | null;
    } = {},
  ) {}

  insertedEvents: Record<string, unknown>[] = [];
  upsertedEntitlements: Record<string, unknown>[] = [];

  auth = {
    admin: {
      getUserById: async (id: string) => {
        const knownUsers = this.options.knownUsers ?? new Set([userId]);
        return knownUsers.has(id)
          ? { data: { user: { id } }, error: null }
          : { data: { user: null }, error: { message: "not found" } };
      },
    },
  };

  from(table: string) {
    return new FakeTable(this, table);
  }
}

class FakeTable {
  constructor(
    private readonly supabase: FakeSupabase,
    private readonly table: string,
  ) {}

  async insert(row: Record<string, unknown>) {
    assertEquals(this.table, "pro_entitlement_events");
    this.supabase.insertedEvents.push(row);
    return { error: this.supabase["options"].insertError ?? null };
  }

  select(_columns: string) {
    assertEquals(this.table, "user_pro_entitlements");
    return {
      eq: (_column: string, _value: string) => ({
        maybeSingle: async () => ({
          data: this.supabase["options"].existingEntitlement ?? null,
          error: null,
        }),
      }),
    };
  }

  async upsert(
    row: Record<string, unknown>,
    _options: Record<string, unknown>,
  ) {
    assertEquals(this.table, "user_pro_entitlements");
    this.supabase.upsertedEntitlements.push(row);
    return { error: null };
  }
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
