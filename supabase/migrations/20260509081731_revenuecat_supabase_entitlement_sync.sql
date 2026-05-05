create extension if not exists pgcrypto;

create table public.user_pro_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,

  is_pro boolean not null default false,
  status text not null default 'inactive'
    check (status in (
      'inactive',
      'active',
      'trial',
      'cancelled_but_active',
      'billing_issue',
      'grace_period',
      'temporary',
      'expired'
    )),

  revenuecat_app_user_id text,
  environment text,
  store text,
  product_id text,
  period_type text,

  purchased_at timestamptz,
  expires_at timestamptz,
  grace_period_expires_at timestamptz,

  last_revenuecat_event_id text unique,
  last_revenuecat_event_type text,
  last_event_at timestamptz,
  last_synced_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.pro_entitlement_events (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,

  revenuecat_event_id text not null unique,
  revenuecat_event_type text not null,

  revenuecat_app_user_id text,
  original_app_user_id text,
  related_app_user_ids text[],

  pro_after boolean not null,
  status_after text not null
    check (status_after in (
      'inactive',
      'active',
      'trial',
      'cancelled_but_active',
      'billing_issue',
      'grace_period',
      'temporary',
      'expired'
    )),

  environment text,
  store text,
  product_id text,
  entitlement_ids text[],

  transaction_id text,
  original_transaction_id text,
  period_type text,

  purchased_at timestamptz,
  expires_at timestamptz,
  grace_period_expires_at timestamptz,
  event_at timestamptz not null,
  processed_at timestamptz not null default now()
);

create index pro_entitlement_events_user_time_idx
  on public.pro_entitlement_events (user_id, event_at desc);

create index pro_entitlement_events_rc_app_user_idx
  on public.pro_entitlement_events (revenuecat_app_user_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger user_pro_entitlements_set_updated_at
before update on public.user_pro_entitlements
for each row
execute function public.set_updated_at();

alter table public.user_pro_entitlements enable row level security;
alter table public.pro_entitlement_events enable row level security;

revoke all on table public.user_pro_entitlements from anon, authenticated;
revoke all on table public.pro_entitlement_events from anon, authenticated;

grant usage on schema public to authenticated, service_role;
grant select on table public.user_pro_entitlements to authenticated;
grant select, insert, update, delete on table public.user_pro_entitlements to service_role;
grant select, insert, update, delete on table public.pro_entitlement_events to service_role;

create policy "Users can read own pro entitlement"
on public.user_pro_entitlements
for select
to authenticated
using ((select auth.uid()) = user_id);
