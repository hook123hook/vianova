-- ============================================================
-- ViaNova | Complete Supabase Schema
-- Run in: Supabase Dashboard > SQL Editor
-- Safe to re-run (idempotent — uses IF NOT EXISTS)
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- 1. CASE ASSESSMENTS (Danışmanlık başvuru formları)
-- ──────────────────────────────────────────────────────────────
create table if not exists public.case_assessments (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  first_name text not null,
  last_name text not null,
  phone text,
  gender_identity text,
  relationship_status text,
  nationality text not null,
  partner_nationality text,
  destination text not null,
  package text,
  fee numeric,
  service text,
  previous_refusal text,
  message text not null,
  lang text default 'en',
  status text not null default 'new',
  admin_notes text
);

-- Upgrade existing installations
alter table public.case_assessments add column if not exists status text not null default 'new';
alter table public.case_assessments add column if not exists admin_notes text;

create index if not exists case_assessments_created_idx on public.case_assessments (created_at desc);
create index if not exists case_assessments_status_idx on public.case_assessments (status);

alter table public.case_assessments enable row level security;

-- RLS: anonymous = NO access. Admins (authenticated) = full read/write/delete.
drop policy if exists "admins_select_cases" on public.case_assessments;
create policy "admins_select_cases"
  on public.case_assessments for select
  to authenticated
  using (true);

drop policy if exists "admins_update_cases" on public.case_assessments;
create policy "admins_update_cases"
  on public.case_assessments for update
  to authenticated
  using (true);

drop policy if exists "admins_delete_cases" on public.case_assessments;
create policy "admins_delete_cases"
  on public.case_assessments for delete
  to authenticated
  using (true);

-- Realtime: pushes new submissions to the open admin panel instantly.
do $$ begin
  alter publication supabase_realtime add table public.case_assessments;
exception when duplicate_object then null;
end $$;


-- ──────────────────────────────────────────────────────────────
-- 2. XMR ADDRESS POOL (Monero adres havuzu)
-- ──────────────────────────────────────────────────────────────
create table if not exists xmr_address_pool (
  id bigint generated always as identity primary key,
  address text unique not null,
  subaddress_index int unique not null,
  status text not null default 'unused' check (status in ('unused','assigned')),
  invoice_id uuid,
  created_at timestamptz not null default now()
);

alter table xmr_address_pool enable row level security;

drop policy if exists admins_select_address_pool on xmr_address_pool;
create policy admins_select_address_pool on xmr_address_pool
  for select to authenticated using (true);

-- Bridge uses service_role to INSERT new addresses into the pool
drop policy if exists service_insert_address_pool on xmr_address_pool;
create policy service_insert_address_pool on xmr_address_pool
  for insert to service_role with check (true);


-- ──────────────────────────────────────────────────────────────
-- 3. XMR INVOICES (Ödeme faturaları)
-- ──────────────────────────────────────────────────────────────
create table if not exists xmr_invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_no text unique not null,
  address text unique not null,
  subaddress_index int not null,
  amount_eur numeric(12,2) not null,
  amount_xmr numeric(14,8) not null,
  fx_rate numeric(12,6) not null,
  safety_pct numeric(6,2) not null default 3.00,
  package_id text not null,
  stage text not null default 'full' check (stage in ('retainer','remainder','full')),
  status text not null default 'pending' check (status in ('pending','partial','credited','expired','void')),
  confirmations int not null default 0,
  received_amount_xmr numeric(14,8),
  tx_hash text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  channel text not null default 'xmr' check (channel in ('xmr','card','psp'))
);

alter table xmr_invoices enable row level security;

drop policy if exists admins_select_xmr_invoices on xmr_invoices;
create policy admins_select_xmr_invoices on xmr_invoices
  for select to authenticated using (true);

drop policy if exists admins_update_xmr_invoices on xmr_invoices;
create policy admins_update_xmr_invoices on xmr_invoices
  for update to authenticated using (true);

-- Bridge uses service_role to update invoice status (confirmations, credited, etc.)
drop policy if exists service_update_xmr_invoices on xmr_invoices;
create policy service_update_xmr_invoices on xmr_invoices
  for update to service_role using (true);

do $$ begin
  alter publication supabase_realtime add table public.xmr_invoices;
exception when duplicate_object then null;
end $$;


-- ──────────────────────────────────────────────────────────────
-- 4. XMR PAYMENTS (Ödeme defteri — geri dönüşümsüz)
-- ──────────────────────────────────────────────────────────────
create table if not exists xmr_payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references xmr_invoices(id) on delete cascade,
  tx_hash text not null,
  amount_xmr numeric(14,8) not null,
  confirmations int not null default 0,
  detected_at timestamptz not null default now(),
  unique (invoice_id, tx_hash)
);

alter table xmr_payments enable row level security;

drop policy if exists admins_select_xmr_payments on xmr_payments;
create policy admins_select_xmr_payments on xmr_payments
  for select to authenticated using (true);

-- Bridge uses service_role to insert payment records
drop policy if exists service_insert_xmr_payments on xmr_payments;
create policy service_insert_xmr_payments on xmr_payments
  for insert to service_role with check (true);

do $$ begin
  alter publication supabase_realtime add table public.xmr_payments;
exception when duplicate_object then null;
end $$;


-- ──────────────────────────────────────────────────────────────
-- 5. POP XMR ADDRESS FUNCTION (Atomik adres tahsisi)
-- ──────────────────────────────────────────────────────────────
create or replace function pop_xmr_address()
returns table (address text, subaddress_index int)
language plpgsql security definer
as $$
declare
  v xmr_address_pool%rowtype;
begin
  select * into v
    from xmr_address_pool
   where status = 'unused'
   order by id
   limit 1
   for update skip locked;
  if v.id is null then
    raise exception 'NO_ADDRESS_AVAILABLE';
  end if;
  update xmr_address_pool set status = 'assigned' where id = v.id;
  return query select v.address, v.subaddress_index;
end $$;

revoke all on function pop_xmr_address() from public;
grant execute on function pop_xmr_address() to service_role, authenticated;


-- ──────────────────────────────────────────────────────────────
-- 6. UPDATED_AT TRIGGER (Otomatik timestamp güncelleme)
-- ──────────────────────────────────────────────────────────────
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists xmr_invoices_updated_at on xmr_invoices;
create trigger xmr_invoices_updated_at
  before update on xmr_invoices
  for each row
  execute function update_updated_at();
