create table public.reviewer_entitlement_allowlist (
  email text primary key,
  entitlement_id text not null default 'pro',
  expires_at timestamptz not null,
  note text,
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint reviewer_entitlement_allowlist_email_normalized
    check (email = lower(btrim(email)) and email <> '')
);

create trigger reviewer_entitlement_allowlist_set_updated_at
before update on public.reviewer_entitlement_allowlist
for each row
execute function public.set_updated_at();

alter table public.reviewer_entitlement_allowlist enable row level security;

revoke all on table public.reviewer_entitlement_allowlist from anon, authenticated;
grant select, insert, update, delete on table public.reviewer_entitlement_allowlist to service_role;
