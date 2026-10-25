-- Run this in the Supabase SQL editor.
create extension if not exists pgcrypto;

create table if not exists public.encrypted_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  record_type text not null check (record_type in ('state', 'memory', 'key_bundle')),
  ciphertext text not null,
  nonce text not null,
  wrapped_key text,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.caregiver_grants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  caregiver_id uuid not null references auth.users(id) on delete cascade,
  permission text not null check (permission in ('read_schedule', 'read_memories')),
  created_at timestamptz not null default now(),
  unique(owner_id, caregiver_id, permission),
  check(owner_id <> caregiver_id)
);

create table if not exists public.billing_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  status text not null,
  current_period_end timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.encrypted_records enable row level security;
alter table public.caregiver_grants enable row level security;
alter table public.billing_subscriptions enable row level security;

drop policy if exists encrypted_records_owner_or_granted on public.encrypted_records;
create policy encrypted_records_owner_or_granted on public.encrypted_records
  for all using (
    auth.uid() = user_id
    or exists (
      select 1 from public.caregiver_grants g
      where g.owner_id = encrypted_records.user_id
        and g.caregiver_id = auth.uid()
        and g.permission = 'read_memories'
    )
  ) with check (auth.uid() = user_id);

drop policy if exists caregiver_grants_participants on public.caregiver_grants;
create policy caregiver_grants_participants on public.caregiver_grants
  for all using (auth.uid() = owner_id or auth.uid() = caregiver_id)
  with check (auth.uid() = owner_id);

drop policy if exists billing_owner_read on public.billing_subscriptions;
create policy billing_owner_read on public.billing_subscriptions
  for select using (auth.uid() = user_id);

create or replace function public.touch_updated_at()
returns trigger language plpgsql security invoker as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists encrypted_records_touch on public.encrypted_records;
create trigger encrypted_records_touch before update on public.encrypted_records
for each row execute procedure public.touch_updated_at();

-- Webhook code using the Supabase service-role key may upsert billing_subscriptions.
-- Never expose the service-role key to the browser and never disable RLS in a client.
