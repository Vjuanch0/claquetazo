-- ALUNA · Diario (semillas). Pégalo UNA sola vez en Supabase: SQL Editor -> New query -> pegar -> Run.
-- Necesita que ya hayas corrido supabase-setup.sql (usa la función tocar_updated_at).

create table if not exists public.semillas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tipo text not null default 'random',
  titulo text not null default '' check (char_length(titulo) <= 200),
  contenido text not null default '' check (char_length(contenido) <= 30000),
  nota numeric(2,1) check (nota is null or (nota >= 1 and nota <= 5)),
  publica boolean not null default false,
  trazos jsonb,
  hojas text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists semillas_user_idx on public.semillas (user_id, created_at desc);

drop trigger if exists semillas_updated on public.semillas;
create trigger semillas_updated
  before update on public.semillas
  for each row execute function public.tocar_updated_at();

alter table public.semillas enable row level security;

drop policy if exists "semillas: publicas para todos" on public.semillas;
create policy "semillas: publicas para todos" on public.semillas
  for select to anon, authenticated
  using (publica = true);

drop policy if exists "semillas: el dueño ve las suyas" on public.semillas;
create policy "semillas: el dueño ve las suyas" on public.semillas
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "semillas: el dueño siembra" on public.semillas;
create policy "semillas: el dueño siembra" on public.semillas
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "semillas: el dueño edita" on public.semillas;
create policy "semillas: el dueño edita" on public.semillas
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "semillas: el dueño borra" on public.semillas;
create policy "semillas: el dueño borra" on public.semillas
  for delete to authenticated
  using (user_id = (select auth.uid()));

grant select on public.semillas to anon;
grant select, insert, update, delete on public.semillas to authenticated;
