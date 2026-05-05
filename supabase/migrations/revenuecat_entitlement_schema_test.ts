Deno.test("entitlement tables cascade when Supabase auth users are deleted", async () => {
  const sql = await Deno.readTextFile(
    "./20260509081731_revenuecat_supabase_entitlement_sync.sql",
  );

  assertIncludes(
    sql,
    "user_id uuid primary key references auth.users(id) on delete cascade",
  );
  assertIncludes(
    sql,
    "user_id uuid not null references auth.users(id) on delete cascade",
  );
});

function assertIncludes(source: string, expected: string) {
  if (!source.includes(expected)) {
    throw new Error(`Expected migration to include: ${expected}`);
  }
}
