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

Deno.test("reviewer allowlist is service-role only and requires normalized email", async () => {
  const sql = await Deno.readTextFile(
    "./20260510113000_reviewer_temporary_entitlement.sql",
  );

  assertIncludes(sql, "create table public.reviewer_entitlement_allowlist");
  assertIncludes(
    sql,
    "check (email = lower(btrim(email)) and email <> '')",
  );
  assertIncludes(
    sql,
    "revoke all on table public.reviewer_entitlement_allowlist from anon, authenticated",
  );
  assertIncludes(
    sql,
    "grant select, insert, update, delete on table public.reviewer_entitlement_allowlist to service_role",
  );
});

function assertIncludes(source: string, expected: string) {
  if (!source.includes(expected)) {
    throw new Error(`Expected migration to include: ${expected}`);
  }
}
