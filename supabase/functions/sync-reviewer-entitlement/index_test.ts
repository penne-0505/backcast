import { handleSyncReviewerEntitlement } from "./index.ts";

Deno.test("rejects unauthenticated requests", async () => {
  const response = await handleSyncReviewerEntitlement(
    new Request("http://localhost/sync-reviewer-entitlement", {
      method: "POST",
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body.error, "unauthorized");
});

Deno.test("applies active allowlist as temporary entitlement", async () => {
  const admin = new FakeAdminClient({
    allowlist: {
      email: "reviewer@example.com",
      entitlement_id: "pro",
      expires_at: "2026-06-10T00:00:00.000Z",
      disabled_at: null,
    },
  });

  const response = await handleSyncReviewerEntitlement(
    authenticatedRequest(),
    dependencies({ admin }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.applied, true);
  assertEquals(admin.upserts.length, 1);
  assertEquals(admin.upserts[0].is_pro, true);
  assertEquals(admin.upserts[0].status, "temporary");
  assertEquals(admin.upserts[0].user_id, userId);
});

Deno.test("does not grant expired allowlist entries", async () => {
  const admin = new FakeAdminClient({
    allowlist: {
      email: "reviewer@example.com",
      entitlement_id: "pro",
      expires_at: "2026-05-01T00:00:00.000Z",
      disabled_at: null,
    },
  });

  const response = await handleSyncReviewerEntitlement(
    authenticatedRequest(),
    dependencies({ admin }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.applied, false);
  assertEquals(body.reason, "allowlist_inactive");
  assertEquals(admin.upserts.length, 0);
});

Deno.test("clears existing temporary entitlement when allowlist is disabled", async () => {
  const admin = new FakeAdminClient({
    allowlist: {
      email: "reviewer@example.com",
      entitlement_id: "pro",
      expires_at: "2026-06-10T00:00:00.000Z",
      disabled_at: "2026-05-10T00:00:00.000Z",
    },
    existingEntitlement: {
      is_pro: true,
      status: "temporary",
      expires_at: "2026-06-10T00:00:00.000Z",
    },
  });

  const response = await handleSyncReviewerEntitlement(
    authenticatedRequest(),
    dependencies({ admin }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.cleared, true);
  assertEquals(admin.upserts.length, 1);
  assertEquals(admin.upserts[0].is_pro, false);
  assertEquals(admin.upserts[0].status, "inactive");
});

Deno.test("preserves existing paid entitlement", async () => {
  const admin = new FakeAdminClient({
    allowlist: {
      email: "reviewer@example.com",
      entitlement_id: "pro",
      expires_at: "2026-06-10T00:00:00.000Z",
      disabled_at: null,
    },
    existingEntitlement: {
      is_pro: true,
      status: "active",
      expires_at: "2026-06-10T00:00:00.000Z",
    },
  });

  const response = await handleSyncReviewerEntitlement(
    authenticatedRequest(),
    dependencies({ admin }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.applied, false);
  assertEquals(body.reason, "paid_entitlement_preserved");
  assertEquals(admin.upserts.length, 0);
});

const userId = "11111111-1111-4111-8111-111111111111";

function authenticatedRequest() {
  return new Request("http://localhost/sync-reviewer-entitlement", {
    method: "POST",
    headers: { Authorization: "Bearer user-jwt" },
  });
}

function dependencies(
  options: { admin: FakeAdminClient; email?: string | null },
) {
  return {
    createUserClient: () =>
      ({
        auth: {
          getUser: async (_jwt: string) => ({
            data: {
              user: {
                id: userId,
                email: options.email ?? "Reviewer@Example.com",
              },
            },
            error: null,
          }),
        },
      }) as never,
    createAdminClient: () => options.admin as never,
    now: () => new Date("2026-05-10T00:00:00.000Z"),
  };
}

class FakeAdminClient {
  constructor(
    private readonly options: {
      allowlist?: Record<string, unknown> | null;
      existingEntitlement?: Record<string, unknown> | null;
    } = {},
  ) {}

  upserts: Record<string, unknown>[] = [];

  from(table: string) {
    return new FakeTable(this, table);
  }

  allowlist() {
    return this.options.allowlist ?? null;
  }

  existingEntitlement() {
    return this.options.existingEntitlement ?? null;
  }
}

class FakeTable {
  constructor(
    private readonly admin: FakeAdminClient,
    private readonly table: string,
  ) {}

  select(_columns: string) {
    return {
      eq: (_column: string, _value: string) => ({
        maybeSingle: async () => {
          if (this.table === "reviewer_entitlement_allowlist") {
            return { data: this.admin.allowlist(), error: null };
          }
          if (this.table === "user_pro_entitlements") {
            return { data: this.admin.existingEntitlement(), error: null };
          }
          throw new Error(`Unexpected table: ${this.table}`);
        },
      }),
    };
  }

  async upsert(
    row: Record<string, unknown>,
    _options: Record<string, unknown>,
  ) {
    if (this.table !== "user_pro_entitlements") {
      throw new Error(`Unexpected upsert table: ${this.table}`);
    }
    this.admin.upserts.push(row);
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
