/// The SQL that prepares a Supabase project for syncing. Kept in sync with
/// `supabase/setup.sql`; shown in the app so it can be copied.
const supabaseSetupSql = r'''
-- منظم دراستي — تجهيز المزامنة على Supabase
-- Study Planner — sync setup. Run once in the Supabase SQL Editor.
-- Safe to run again.

create table if not exists public.planner_state (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  data jsonb not null,
  version bigint not null default 1,
  updated_at timestamptz not null default now()
);

-- Every account can only see and change its own row.
alter table public.planner_state enable row level security;

drop policy if exists "planner_state_select_own" on public.planner_state;
create policy "planner_state_select_own" on public.planner_state
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "planner_state_insert_own" on public.planner_state;
create policy "planner_state_insert_own" on public.planner_state
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "planner_state_update_own" on public.planner_state;
create policy "planner_state_update_own" on public.planner_state
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant select, insert, update on public.planner_state to authenticated;

-- Live updates: devices hear about each other's changes right away.
do $$
begin
  alter publication supabase_realtime add table public.planner_state;
exception
  when duplicate_object then null;
end $$;
''';
