-- ALUNA v24 · Tejidos. Pégalo UNA sola vez en Supabase: SQL Editor -> New query -> pegar -> Run.
-- Necesita que ya hayas corrido supabase-setup.sql y supabase-diario.sql (supabase-hojas.sql es opcional).
-- Qué hace: (1) agrega a las semillas el tejido, la ficha, las etiquetas y la fecha; (2) pone candado para que
-- Raíz y Sueños nunca sean públicos; (3) pasa tus reseñas viejas a su tejido nuevo sin borrar nada.

-- 1. Columnas nuevas
alter table public.semillas add column if not exists tejido text;
alter table public.semillas add column if not exists datos jsonb not null default '{}'::jsonb;
alter table public.semillas add column if not exists etiquetas text[] not null default '{}';
alter table public.semillas add column if not exists fecha date;

-- 2. Tipos que desaparecen y tejido de lo que ya había
update public.semillas set tipo = 'momento' where tipo = 'gratitud';
update public.semillas set tejido = case tipo
    when 'idea' then 'ideas'
    when 'aprendi' then 'saber'
    when 'sueno' then 'suenos'
    when 'lugar' then 'ruta'
    else 'raiz'
  end
  where tejido is null;
alter table public.semillas alter column tejido set default 'raiz';
alter table public.semillas alter column tejido set not null;

-- 3. Candados: Raíz y Sueños jamás públicos; la ficha no puede pesar de más
update public.semillas set publica = false where publica and tejido in ('raiz', 'suenos');
alter table public.semillas drop constraint if exists semillas_privado_chk;
alter table public.semillas add constraint semillas_privado_chk check (not (publica and tejido in ('raiz', 'suenos')));
alter table public.semillas drop constraint if exists semillas_datos_chk;
alter table public.semillas add constraint semillas_datos_chk check (octet_length(datos::text) <= 20000);
alter table public.semillas drop constraint if exists semillas_etiquetas_chk;
alter table public.semillas add constraint semillas_etiquetas_chk check (coalesce(cardinality(etiquetas), 0) <= 24);

create index if not exists semillas_tejido_idx on public.semillas (user_id, tejido, created_at desc);

-- 4. Tus reseñas viejas pasan a ser fichas (película -> Escena, serie/anime -> Capítulo, videojuego -> Partida, libro -> Páginas;
--    lo demás queda como nota en Raíz). La tabla vieja NO se borra: queda de respaldo.
insert into public.semillas (id, user_id, tipo, titulo, contenido, nota, publica, tejido, datos, etiquetas, fecha, created_at, updated_at)
select
  r.id, r.user_id,
  case r.categoria when 'cine' then 'pelicula' when 'series' then 'serie' when 'anime' then 'serie'
                   when 'videojuegos' then 'juego' when 'libros' then 'libro' else 'random' end,
  left(r.titulo, 200),
  left(btrim(regexp_replace(replace(replace(replace(replace(replace(
        regexp_replace(regexp_replace(coalesce(r.resenia, ''), '</(p|h2|h3|blockquote|li)>', E'\n\n', 'gi'), '<[^>]+>', '', 'g'),
        '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&amp;', '&'),
        E'\n{3,}', E'\n\n', 'g')), 30000),
  r.nota,
  case when r.categoria in ('cine', 'series', 'anime', 'videojuegos', 'libros') then r.publica else false end,
  case r.categoria when 'cine' then 'escena' when 'series' then 'capitulo' when 'anime' then 'capitulo'
                   when 'videojuegos' then 'partida' when 'libros' then 'paginas' else 'raiz' end,
  jsonb_strip_nulls(jsonb_build_object(
    'migrada', 'resena',
    'img', r.foto_path, 'thumb', r.thumb_path,
    'estreno', nullif(r.fecha, ''),
    'veredicto', nullif(r.veredicto, ''),
    'descripcion', nullif(left(r.descripcion, 500), ''))),
  coalesce(r.generos[1:20], '{}'),
  r.created_at::date, r.created_at, r.updated_at
from public.reviews r
where not exists (select 1 from public.semillas s where s.id = r.id)
  and coalesce((to_jsonb(r) ->> 'borrador')::boolean, false) = false;

-- Si la reseña vieja tenía una hoja, ahora cuelga de la ficha nueva (solo si ya existe la tabla de hojas)
do $$
begin
  if to_regclass('public.hojas') is not null then
    update public.hojas set ref_tipo = 'semilla'
      where ref_tipo = 'resena'
        and ref_id in (select id::text from public.semillas where datos ->> 'migrada' = 'resena');
  end if;
end $$;
