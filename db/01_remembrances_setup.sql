-- ============================================================================
-- drbbsingh remembrances — table, RLS policies, backfill
-- Run once in the Supabase SQL editor (same project as the relocate app).
-- Safe to re-run: uses IF NOT EXISTS and ON CONFLICT guards where possible.
-- ============================================================================

-- ---------- 1. Table ----------
create table if not exists public.remembrances (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  connection   text,
  message      text not null,
  status       text not null default 'pending'
               check (status in ('pending','approved')),
  created_at   timestamptz not null default now(),
  approved_at  timestamptz
);

create index if not exists remembrances_status_created_idx
  on public.remembrances (status, created_at desc);

-- ---------- 2. Row-Level Security ----------
alter table public.remembrances enable row level security;

-- Drop existing policies if re-running, so the script is idempotent.
drop policy if exists "anon can insert pending"  on public.remembrances;
drop policy if exists "anon can read approved"   on public.remembrances;
drop policy if exists "admin full access"        on public.remembrances;

-- Anonymous visitors: may insert a row, but only with status='pending'
-- and approved_at NULL. They cannot self-approve.
create policy "anon can insert pending"
  on public.remembrances
  for insert
  to anon
  with check (
    status = 'pending'
    and approved_at is null
  );

-- Anonymous visitors: may read approved rows only. Pending submissions
-- are invisible to the public page.
create policy "anon can read approved"
  on public.remembrances
  for select
  to anon
  using (status = 'approved');

-- Admin (pinned to pilotbk@gmail.com via JWT): full access. Anyone else
-- who authenticates against this Supabase project (e.g. via the relocate
-- app) gets nothing extra on this table.
create policy "admin full access"
  on public.remembrances
  for all
  to authenticated
  using       (auth.jwt() ->> 'email' = 'pilotbk@gmail.com')
  with check  (auth.jwt() ->> 'email' = 'pilotbk@gmail.com');

-- ---------- 3. Backfill existing approved entries ----------
-- Timestamps reflect the actual git commit times when each was approved.
insert into public.remembrances (name, connection, message, status, created_at, approved_at)
values
  (
    'RAJESH SINGH',
    'My Uncle',
    E'My uncle was a very intelligent and hardworking person. He worked as an internal scientist and was very dedicated to his work. He was very kind and humble in nature.\nHe always encouraged me to study and learn new things. I learned many good values from him. I have many beautiful memories with him which I will always cherish.Now he is no more with us, but his teachings and memories will always remain in my heart. I will never forget him.',
    'approved',
    '2026-05-02 13:51:42+00',
    '2026-05-02 13:51:42+00'
  ),
  (
    'Raunak Singh',
    'Grandson',
    'My Nana Ji was a man who was loving, wise, and full of knowledge. I have learned many values from him that will serve me throughout my life. Even though you are not here anymore, your blessings will keep me safe. You will always be alive in my heart. Om Shanti. 🙏',
    'approved',
    '2026-05-02 13:51:42+00',
    '2026-05-02 13:51:42+00'
  ),
  (
    'Vishal Singh',
    'Grandfather',
    'To the man who taught me so much about life.  I carry your lessons in my heart and hope to make you proud. Your memory is a treasure we will never lose.',
    'approved',
    '2026-05-01 18:24:58+00',
    '2026-05-01 18:24:58+00'
  ),
  (
    'Anjali Singh',
    'Granddaughter',
    'Grandpa, your love, wisdom, and warmth meant everything to me. I will always cherish the memories we shared. You will be deeply missed.',
    'approved',
    '2026-05-01 18:24:58+00',
    '2026-05-01 18:24:58+00'
  );

-- ---------- 4. Sanity checks (run separately to verify) ----------
-- select count(*) from public.remembrances;                       -- expect 4
-- select status, count(*) from public.remembrances group by 1;    -- all 'approved'
