-- ALUNA · Hojas (collage: lápiz, texto y recortes). Pégalo UNA sola vez en Supabase: SQL Editor -> New query -> pegar -> Run.
-- Necesita que ya hayas corrido supabase-setup.sql (usa la función tocar_updated_at) y supabase-diario.sql.

create table if not exists public.hojas (
  ref_tipo text not null check (ref_tipo in ('semilla', 'resena')),
  ref_id text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  datos jsonb not null check (octet_length(datos::text) <= 4500000),
  miniatura text check (miniatura is null or char_length(miniatura) <= 200000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (ref_tipo, ref_id)
);

create index if not exists hojas_user_idx on public.hojas (user_id);

drop trigger if exists hojas_updated on public.hojas;
create trigger hojas_updated
  before update on public.hojas
  for each row execute function public.tocar_updated_at();

alter table public.hojas enable row level security;

-- Cualquiera ve la hoja de una semilla o reseña que sea pública
drop policy if exists "hojas: las de cosas publicas" on public.hojas;
create policy "hojas: las de cosas publicas" on public.hojas
  for select to anon, authenticated
  using (
    (ref_tipo = 'semilla' and exists (select 1 from public.semillas s where s.id::text = ref_id and s.publica = true))
    or (ref_tipo = 'resena' and exists (select 1 from public.reviews r where r.id::text = ref_id and r.publica = true))
  );

drop policy if exists "hojas: el dueño ve las suyas" on public.hojas;
create policy "hojas: el dueño ve las suyas" on public.hojas
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "hojas: el dueño pega" on public.hojas;
create policy "hojas: el dueño pega" on public.hojas
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "hojas: el dueño edita" on public.hojas;
create policy "hojas: el dueño edita" on public.hojas
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "hojas: el dueño borra" on public.hojas;
create policy "hojas: el dueño borra" on public.hojas
  for delete to authenticated
  using (user_id = (select auth.uid()));

grant select on public.hojas to anon;
grant select, insert, update, delete on public.hojas to authenticated;
