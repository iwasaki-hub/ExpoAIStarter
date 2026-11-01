-- ExpoAIStarter: initial accounting schema
-- Target: Supabase PostgreSQL
-- Apply only to a fresh development project after reviewing this migration.
-- This migration creates the data model and RLS foundation.
-- Journal posting RPC / balanced-entry enforcement is intentionally a follow-up migration.

begin;

create extension if not exists pgcrypto;

-- Profiles are linked to Supabase Auth users.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  business_name text not null,
  tax_filing_type text not null default 'blue'
    check (tax_filing_type in ('blue', 'white')),
  fiscal_year_start_month smallint not null default 1
    check (fiscal_year_start_month = 1),
  currency text not null default 'JPY'
    check (currency = 'JPY'),
  tax_status text not null default 'unknown'
    check (tax_status in ('unknown', 'exempt', 'taxable')),
  invoice_registered boolean not null default false,
  accounting_method text not null default 'tax_inclusive'
    check (accounting_method in ('tax_inclusive', 'tax_exclusive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  code text not null,
  name text not null,
  account_type text not null
    check (account_type in ('asset', 'liability', 'equity', 'revenue', 'expense')),
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, code),
  unique (business_id, id)
);

create table public.tax_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  code text not null,
  name text not null,
  tax_rate_basis_points integer not null default 0
    check (tax_rate_basis_points in (0, 800, 1000)),
  tax_treatment text not null default 'out_of_scope'
    check (tax_treatment in ('taxable_purchase', 'taxable_sales', 'exempt', 'non_taxable', 'out_of_scope')),
  valid_from date,
  valid_until date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_id, code),
  unique (business_id, id),
  check (valid_until is null or valid_from is null or valid_until >= valid_from)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  transaction_date date not null,
  transaction_type text not null
    check (transaction_type in ('income', 'expense', 'transfer')),
  account_id uuid not null,
  amount_yen bigint not null check (amount_yen > 0),
  counterparty text,
  payment_status text not null default 'unpaid'
    check (payment_status in ('paid', 'unpaid', 'partial')),
  payment_account_id uuid,
  settled_on date,
  tax_category_id uuid,
  description text,
  idempotency_key uuid,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, id),
  unique (business_id, idempotency_key),
  foreign key (business_id, account_id)
    references public.accounts(business_id, id),
  foreign key (business_id, payment_account_id)
    references public.accounts(business_id, id),
  foreign key (business_id, tax_category_id)
    references public.tax_categories(business_id, id),
  check (
    (payment_status = 'unpaid' and settled_on is null)
    or
    (payment_status in ('paid', 'partial'))
  )
);

create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  transaction_id uuid,
  entry_date date not null,
  description text,
  status text not null default 'draft'
    check (status in ('draft', 'posted', 'reversed')),
  reverses_entry_id uuid references public.journal_entries(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, id),
  foreign key (business_id, transaction_id)
    references public.transactions(business_id, id)
);

create table public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  journal_entry_id uuid not null,
  account_id uuid not null,
  line_number integer not null check (line_number > 0),
  debit_yen bigint not null default 0 check (debit_yen >= 0),
  credit_yen bigint not null default 0 check (credit_yen >= 0),
  description text,
  created_at timestamptz not null default now(),
  foreign key (business_id, journal_entry_id)
    references public.journal_entries(business_id, id) on delete cascade,
  foreign key (business_id, account_id)
    references public.accounts(business_id, id),
  unique (journal_entry_id, line_number),
  check (
    (debit_yen > 0 and credit_yen = 0)
    or
    (credit_yen > 0 and debit_yen = 0)
  )
);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  transaction_id uuid not null,
  storage_path text not null,
  file_name text not null,
  content_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (business_id, transaction_id)
    references public.transactions(business_id, id) on delete cascade,
  unique (business_id, storage_path)
);

-- Useful indexes for common filters and joins.
create index businesses_user_id_idx on public.businesses(user_id);
create index accounts_business_active_idx on public.accounts(business_id, is_active);
create index transactions_business_date_idx on public.transactions(business_id, transaction_date desc);
create index transactions_business_type_date_idx on public.transactions(business_id, transaction_type, transaction_date desc);
create index journal_entries_business_date_idx on public.journal_entries(business_id, entry_date desc);
create index journal_entries_transaction_idx on public.journal_entries(transaction_id);
create index journal_lines_entry_idx on public.journal_lines(journal_entry_id, line_number);
create index attachments_transaction_idx on public.attachments(transaction_id);

-- Automatically maintain updated_at.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger businesses_set_updated_at
before update on public.businesses
for each row execute function public.set_updated_at();

create trigger accounts_set_updated_at
before update on public.accounts
for each row execute function public.set_updated_at();

create trigger transactions_set_updated_at
before update on public.transactions
for each row execute function public.set_updated_at();

create trigger journal_entries_set_updated_at
before update on public.journal_entries
for each row execute function public.set_updated_at();

-- Create a profile after Supabase Auth signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Ownership helper. SECURITY DEFINER avoids recursive RLS evaluation on businesses.
create or replace function public.owns_business(target_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.businesses b
    where b.id = target_business_id
      and b.user_id = auth.uid()
  );
$$;

revoke all on function public.owns_business(uuid) from public;
grant execute on function public.owns_business(uuid) to authenticated;

-- Enable RLS on all user-owned tables.
alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.accounts enable row level security;
alter table public.tax_categories enable row level security;
alter table public.transactions enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;
alter table public.attachments enable row level security;

create policy "profiles_select_own"
on public.profiles for select to authenticated
using (id = auth.uid());

create policy "profiles_update_own"
on public.profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "businesses_select_own"
on public.businesses for select to authenticated
using (user_id = auth.uid());

create policy "businesses_insert_own"
on public.businesses for insert to authenticated
with check (user_id = auth.uid());

create policy "businesses_update_own"
on public.businesses for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "businesses_delete_own"
on public.businesses for delete to authenticated
using (user_id = auth.uid());

create policy "accounts_select_owned"
on public.accounts for select to authenticated
using (public.owns_business(business_id));

create policy "accounts_insert_owned"
on public.accounts for insert to authenticated
with check (public.owns_business(business_id));

create policy "accounts_update_owned"
on public.accounts for update to authenticated
using (public.owns_business(business_id))
with check (public.owns_business(business_id));

create policy "accounts_delete_owned"
on public.accounts for delete to authenticated
using (public.owns_business(business_id));

create policy "tax_categories_select_owned"
on public.tax_categories for select to authenticated
using (public.owns_business(business_id));

create policy "tax_categories_insert_owned"
on public.tax_categories for insert to authenticated
with check (public.owns_business(business_id));

create policy "tax_categories_update_owned"
on public.tax_categories for update to authenticated
using (public.owns_business(business_id))
with check (public.owns_business(business_id));

create policy "tax_categories_delete_owned"
on public.tax_categories for delete to authenticated
using (public.owns_business(business_id));

create policy "transactions_select_owned"
on public.transactions for select to authenticated
using (public.owns_business(business_id));

create policy "transactions_insert_owned"
on public.transactions for insert to authenticated
with check (
  public.owns_business(business_id)
  and (created_by is null or created_by = auth.uid())
);

create policy "transactions_update_owned"
on public.transactions for update to authenticated
using (public.owns_business(business_id))
with check (
  public.owns_business(business_id)
  and (created_by is null or created_by = auth.uid())
);

create policy "transactions_delete_owned"
on public.transactions for delete to authenticated
using (public.owns_business(business_id));

create policy "journal_entries_select_owned"
on public.journal_entries for select to authenticated
using (public.owns_business(business_id));

create policy "journal_entries_insert_owned"
on public.journal_entries for insert to authenticated
with check (
  public.owns_business(business_id)
  and status = 'draft'
  and (created_by is null or created_by = auth.uid())
);

-- Client-side direct edits are limited to draft entries.
-- Posting/reversal will be performed by a validated server-side RPC in a later migration.
create policy "journal_entries_update_draft_owned"
on public.journal_entries for update to authenticated
using (
  public.owns_business(business_id)
  and status = 'draft'
)
with check (
  public.owns_business(business_id)
  and status = 'draft'
  and (created_by is null or created_by = auth.uid())
);

create policy "journal_entries_delete_draft_owned"
on public.journal_entries for delete to authenticated
using (
  public.owns_business(business_id)
  and status = 'draft'
);

create policy "journal_lines_select_owned"
on public.journal_lines for select to authenticated
using (public.owns_business(business_id));

create policy "journal_lines_insert_draft_owned"
on public.journal_lines for insert to authenticated
with check (
  public.owns_business(business_id)
  and exists (
    select 1
    from public.journal_entries je
    where je.id = journal_entry_id
      and je.business_id = journal_lines.business_id
      and je.status = 'draft'
  )
);

create policy "journal_lines_update_draft_owned"
on public.journal_lines for update to authenticated
using (
  public.owns_business(business_id)
  and exists (
    select 1
    from public.journal_entries je
    where je.id = journal_entry_id
      and je.business_id = journal_lines.business_id
      and je.status = 'draft'
  )
)
with check (
  public.owns_business(business_id)
  and exists (
    select 1
    from public.journal_entries je
    where je.id = journal_entry_id
      and je.business_id = journal_lines.business_id
      and je.status = 'draft'
  )
);

create policy "journal_lines_delete_draft_owned"
on public.journal_lines for delete to authenticated
using (
  public.owns_business(business_id)
  and exists (
    select 1
    from public.journal_entries je
    where je.id = journal_entry_id
      and je.business_id = journal_lines.business_id
      and je.status = 'draft'
  )
);

create policy "attachments_select_owned"
on public.attachments for select to authenticated
using (public.owns_business(business_id));

create policy "attachments_insert_owned"
on public.attachments for insert to authenticated
with check (
  public.owns_business(business_id)
  and (uploaded_by is null or uploaded_by = auth.uid())
);

create policy "attachments_update_owned"
on public.attachments for update to authenticated
using (public.owns_business(business_id))
with check (
  public.owns_business(business_id)
  and (uploaded_by is null or uploaded_by = auth.uid())
);

create policy "attachments_delete_owned"
on public.attachments for delete to authenticated
using (public.owns_business(business_id));

-- Table grants for the client roles. RLS remains the row-level guard.
grant select, insert, update, delete on
  public.profiles,
  public.businesses,
  public.accounts,
  public.tax_categories,
  public.transactions,
  public.journal_entries,
  public.journal_lines,
  public.attachments
to authenticated;

commit;
