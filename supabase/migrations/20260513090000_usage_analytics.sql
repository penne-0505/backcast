create extension if not exists pgcrypto;

create table public.analytics_event_batches (
  id uuid primary key default gen_random_uuid(),
  install_id uuid not null,
  app_version text not null,
  platform text not null
    check (platform in ('android', 'ios', 'macos', 'linux', 'windows', 'web', 'unknown')),
  event_count integer not null check (event_count > 0 and event_count <= 50),
  received_at timestamptz not null default now()
);

create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.analytics_event_batches(id) on delete cascade,
  client_event_id uuid not null,
  install_id uuid not null,
  session_id uuid not null,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  unique (install_id, client_event_id)
);

create index analytics_events_event_time_idx
  on public.analytics_events (event_name, occurred_at desc);

create index analytics_events_install_time_idx
  on public.analytics_events (install_id, occurred_at desc);

alter table public.analytics_event_batches enable row level security;
alter table public.analytics_events enable row level security;

revoke all on table public.analytics_event_batches from anon, authenticated;
revoke all on table public.analytics_events from anon, authenticated;

grant usage on schema public to service_role;
grant select, insert, update, delete on table public.analytics_event_batches to service_role;
grant select, insert, update, delete on table public.analytics_events to service_role;
