import { handleUsageAnalytics } from "./index.ts";

Deno.test("rejects unsupported event names", async () => {
  const response = await handleUsageAnalytics(
    request({
      events: [event({ event_name: "screen_viewed" })],
    }),
    dependencies(new FakeAdminClient()),
  );
  const body = await response.json();

  assertEquals(response.status, 400);
  assertEquals(body.error, "unsupported_event_name");
});

Deno.test("rejects unsupported properties", async () => {
  const response = await handleUsageAnalytics(
    request({
      events: [
        event({
          event_name: "block_added",
          properties: {
            block_type: "action",
            title: "朝の準備",
          },
        }),
      ],
    }),
    dependencies(new FakeAdminClient()),
  );
  const body = await response.json();

  assertEquals(response.status, 400);
  assertEquals(body.error, "unsupported_property");
});

Deno.test("inserts valid batch", async () => {
  const admin = new FakeAdminClient();
  const response = await handleUsageAnalytics(
    request({
      events: [
        event({
          event_name: "block_added",
          properties: {
            block_type: "action",
            block_count_bucket: "2-3",
          },
        }),
      ],
    }),
    dependencies(admin),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.accepted, 1);
  assertEquals(admin.batchInserts.length, 1);
  assertEquals(admin.eventInserts.length, 1);
  assertEquals(admin.eventInserts[0].event_name, "block_added");
});

Deno.test("treats duplicate client event retries as accepted", async () => {
  const admin = new FakeAdminClient({
    bulkEventInsertError: { code: "23505", message: "duplicate key value" },
    duplicateClientEventIds: [eventId],
  });
  const response = await handleUsageAnalytics(
    request({}),
    dependencies(admin),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.duplicate, true);
  assertEquals(body.accepted, 1);
  assertEquals(admin.eventInserts, []);
  assertEquals(admin.deletedBatchIds, [
    "44444444-4444-4444-8444-444444444444",
  ]);
});

Deno.test("keeps new events when a retry batch contains duplicates", async () => {
  const newEventId = "55555555-5555-4555-8555-555555555555";
  const admin = new FakeAdminClient({
    bulkEventInsertError: { code: "23505", message: "duplicate key value" },
    duplicateClientEventIds: [eventId],
  });
  const response = await handleUsageAnalytics(
    request({
      events: [
        event({ id: eventId }),
        event({ id: newEventId }),
      ],
    }),
    dependencies(admin),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.duplicate, true);
  assertEquals(body.accepted, 2);
  assertEquals(admin.eventInserts.map((row) => row.client_event_id), [
    newEventId,
  ]);
  assertEquals(admin.deletedBatchIds, []);
});

Deno.test("cleans up the batch when event insertion fails", async () => {
  const admin = new FakeAdminClient({
    bulkEventInsertError: { code: "XX000", message: "database failure" },
  });
  const response = await handleUsageAnalytics(
    request({}),
    dependencies(admin),
  );
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body.error, "events_insert_failed");
  assertEquals(admin.deletedBatchIds, [
    "44444444-4444-4444-8444-444444444444",
  ]);
});

const installId = "11111111-1111-4111-8111-111111111111";
const sessionId = "22222222-2222-4222-8222-222222222222";
const eventId = "33333333-3333-4333-8333-333333333333";

function request(overrides: Record<string, unknown>) {
  return new Request("http://localhost/usage-analytics", {
    method: "POST",
    body: JSON.stringify({
      app_version: "0.1.0+1",
      platform: "android",
      events: [event({})],
      ...overrides,
    }),
  });
}

function event(overrides: Record<string, unknown>) {
  return {
    id: eventId,
    event_name: "app_opened",
    properties: { launch_source: "cold_start", platform: "android" },
    occurred_at: "2026-05-13T00:00:00.000Z",
    session_id: sessionId,
    install_id: installId,
    ...overrides,
  };
}

function dependencies(admin: FakeAdminClient) {
  return {
    createAdminClient: () => admin as never,
    now: () => new Date("2026-05-13T00:00:00.000Z"),
  };
}

type FakeAdminClientOptions = {
  bulkEventInsertError?: { code: string; message: string } | null;
  duplicateClientEventIds?: string[];
  rowEventInsertError?: { code: string; message: string } | null;
};

class FakeAdminClient {
  constructor(options: FakeAdminClientOptions = {}) {
    this.bulkEventInsertError = options.bulkEventInsertError ?? null;
    this.duplicateClientEventIds = new Set(
      options.duplicateClientEventIds ?? [],
    );
    this.rowEventInsertError = options.rowEventInsertError ?? null;
  }

  bulkEventInsertError: { code: string; message: string } | null;
  duplicateClientEventIds: Set<string>;
  rowEventInsertError: { code: string; message: string } | null;
  batchInserts: Record<string, unknown>[] = [];
  eventInserts: Record<string, unknown>[] = [];
  eventInsertAttempts: Record<string, unknown>[] = [];
  deletedBatchIds: unknown[] = [];

  from(table: string) {
    return new FakeTable(this, table);
  }
}

class FakeTable {
  constructor(
    private readonly admin: FakeAdminClient,
    private readonly table: string,
  ) {}

  insert(rows: Record<string, unknown> | Record<string, unknown>[]) {
    if (this.table === "analytics_event_batches") {
      this.admin.batchInserts.push(rows as Record<string, unknown>);
      return {
        select: (_columns: string) => ({
          single: async () => ({
            data: { id: "44444444-4444-4444-8444-444444444444" },
            error: null,
          }),
        }),
      };
    }
    if (this.table === "analytics_events") {
      const eventRows = Array.isArray(rows) ? rows : [rows];
      this.admin.eventInsertAttempts.push(...eventRows);
      if (Array.isArray(rows)) {
        if (this.admin.bulkEventInsertError) {
          return Promise.resolve({ error: this.admin.bulkEventInsertError });
        }
        this.admin.eventInserts.push(...eventRows);
        return Promise.resolve({ error: null });
      }

      const clientEventId = rows.client_event_id;
      if (
        typeof clientEventId === "string" &&
        this.admin.duplicateClientEventIds.has(clientEventId)
      ) {
        return Promise.resolve({
          error: { code: "23505", message: "duplicate key value" },
        });
      }
      if (this.admin.rowEventInsertError) {
        return Promise.resolve({ error: this.admin.rowEventInsertError });
      }
      this.admin.eventInserts.push(rows);
      return Promise.resolve({ error: null });
    }
    throw new Error(`Unexpected table: ${this.table}`);
  }

  delete() {
    if (this.table !== "analytics_event_batches") {
      throw new Error(`Unexpected delete table: ${this.table}`);
    }
    return {
      eq: (_column: string, value: unknown) => {
        this.admin.deletedBatchIds.push(value);
        return Promise.resolve({ error: null });
      },
    };
  }
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
