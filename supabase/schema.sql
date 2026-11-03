-- aish app — Supabase schema
-- Supabase Dashboard → SQL Editor-ல இதை முழுசா paste பண்ணி Run பண்ணுங்க.
-- மறுபடி run பண்ணாலும் பாதிப்பு இல்ல.

-- ஒவ்வொரு user-க்கும் ஒரு நாள் limit
create table if not exists public.aish_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  daily_limit int not null default 40,
  created_at timestamptz not null default now()
);

-- தினசரி பயன்பாடு
create table if not exists public.aish_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default (now() at time zone 'Asia/Kolkata')::date,
  count int not null default 0,
  primary key (user_id, day)
);

-- Chat history
create table if not exists public.aish_messages (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'tool')),
  content text not null,
  created_at timestamptz not null default now()
);
create index if not exists aish_messages_user_id_idx on public.aish_messages (user_id, id desc);

alter table public.aish_profiles enable row level security;
alter table public.aish_usage enable row level security;
alter table public.aish_messages enable row level security;

-- User தன்னோடதை மட்டும் படிக்கலாம். எழுதுறது Edge Function (service role) மட்டும்.
drop policy if exists "own profile" on public.aish_profiles;
create policy "own profile" on public.aish_profiles for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "own usage" on public.aish_usage;
create policy "own usage" on public.aish_usage for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "own messages" on public.aish_messages;
create policy "own messages" on public.aish_messages for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "delete own messages" on public.aish_messages;
create policy "delete own messages" on public.aish_messages for delete to authenticated using ((select auth.uid()) = user_id);

-- ஒரு AI request-ஐ எண்ணும்; limit தாண்டினா allowed=false. Service role மட்டும் call பண்ண முடியும்.
create or replace function public.aish_consume(p_user uuid)
returns table (allowed boolean, used int, daily_limit int)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit int;
  v_used int;
  v_day date := (now() at time zone 'Asia/Kolkata')::date;
begin
  insert into public.aish_profiles (user_id) values (p_user) on conflict (user_id) do nothing;
  select p.daily_limit into v_limit from public.aish_profiles p where p.user_id = p_user;

  insert into public.aish_usage (user_id, day, count) values (p_user, v_day, 0)
    on conflict (user_id, day) do nothing;
  update public.aish_usage u set count = u.count + 1
    where u.user_id = p_user and u.day = v_day and u.count < v_limit
    returning u.count into v_used;

  if v_used is null then
    select u.count into v_used from public.aish_usage u where u.user_id = p_user and u.day = v_day;
    return query select false, v_used, v_limit;
  else
    return query select true, v_used, v_limit;
  end if;
end;
$$;

revoke all on function public.aish_consume(uuid) from public, anon, authenticated;
grant execute on function public.aish_consume(uuid) to service_role;
