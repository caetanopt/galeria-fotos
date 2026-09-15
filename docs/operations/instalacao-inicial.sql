-- =====================================================================
-- LiveGallery — instalação inicial num projeto Supabase VAZIO
--
-- COMO USAR: painel do Supabase → SQL Editor → New query → colar isto
-- tudo → Run. Demora poucos segundos. Não precisas de terminal nem do
-- Supabase CLI.
--
-- Contém as migrações 0001 a 0009 de supabase/migrations/, pela mesma
-- ordem, seguidas do registo no histórico de migrações do CLI — para o
-- painel mostrar "LAST MIGRATION: 0009_…" e um futuro `supabase db push`
-- responder "Remote database is up to date" em vez de tentar reaplicar
-- tudo por cima.
--
-- ATENÇÃO: é para um projeto NOVO e VAZIO. Se a base já tiver o esquema
-- do LiveGallery, usa `docs/operations/migracoes-pendentes.sql` (0006 em
-- diante, idempotente). Este script não é idempotente: correr duas vezes
-- dá erro de "already exists" na segunda.
--
-- Depois de correr, confirma com `docs/operations/verificar-supabase.sql`.
-- =====================================================================

-- =====================================================================
-- 0001_initial_schema.sql
-- =====================================================================

-- LiveGallery: esquema inicial (Fase 1).
-- Cria as tabelas descritas em CLAUDE.md secção 7, sem políticas de RLS
-- (ver 0003_row_level_security.sql).

create extension if not exists pgcrypto;

create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  display_name text,
  avatar_url text,
  role text not null default 'editor' check (role in ('admin', 'editor')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- google_connections
-- ---------------------------------------------------------------------

create table public.google_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  google_account_email text not null,
  encrypted_refresh_token text not null,
  token_key_version integer not null default 1,
  scope text[] not null default '{}',
  root_folder_id text,
  status text not null default 'active' check (status in ('active', 'revoked', 'error')),
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index google_connections_user_id_idx on public.google_connections (user_id);

create trigger set_google_connections_updated_at
  before update on public.google_connections
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- albums
-- ---------------------------------------------------------------------

create table public.albums (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete restrict,
  google_connection_id uuid not null references public.google_connections (id) on delete restrict,
  title text not null,
  description text,
  slug text not null unique,
  -- referência circular resolvida depois de "photos" existir; ver mais abaixo.
  cover_photo_id uuid,
  drive_folder_id text not null,
  visibility text not null default 'unlisted' check (visibility in ('private', 'unlisted', 'public')),
  upload_enabled boolean not null default true,
  moderation_enabled boolean not null default false,
  download_enabled boolean not null default true,
  event_start_at timestamptz,
  event_end_at timestamptz,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index albums_owner_id_idx on public.albums (owner_id);

create trigger set_albums_updated_at
  before update on public.albums
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- album_share_links
-- ---------------------------------------------------------------------

create table public.album_share_links (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums (id) on delete cascade,
  token_hash text not null unique,
  pin_hash text,
  permissions text[] not null default '{view}' check (permissions <@ array['view', 'upload', 'moderate']::text[]),
  expires_at timestamptz,
  revoked_at timestamptz,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now()
);

create index album_share_links_album_id_idx on public.album_share_links (album_id);

-- ---------------------------------------------------------------------
-- album_sessions
-- ---------------------------------------------------------------------

create table public.album_sessions (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  share_link_id uuid references public.album_share_links (id) on delete cascade,
  permissions text[] not null default '{view}' check (permissions <@ array['view', 'upload', 'moderate']::text[]),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index album_sessions_user_album_expires_idx
  on public.album_sessions (user_id, album_id, expires_at);

-- ---------------------------------------------------------------------
-- photos
-- ---------------------------------------------------------------------

create table public.photos (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums (id) on delete cascade,
  uploaded_by uuid references auth.users (id) on delete set null,
  drive_file_id text not null unique,
  drive_folder_id text not null,
  preview_path text,
  original_filename text not null,
  safe_filename text not null,
  mime_type text not null,
  file_size bigint not null,
  width integer,
  height integer,
  sha256 text,
  blurhash text,
  captured_at timestamptz,
  uploaded_at timestamptz not null default now(),
  status text not null default 'queued' check (
    status in (
      'queued', 'uploading', 'processing', 'pending_review',
      'ready', 'hidden', 'failed', 'deleted'
    )
  ),
  moderation_note text,
  is_featured boolean not null default false,
  sort_order bigint not null default (floor(extract(epoch from clock_timestamp()) * 1000)),
  error_code text,
  error_message text,
  deleted_at timestamptz
);

create index photos_album_status_sort_idx
  on public.photos (album_id, status, sort_order desc);
create index photos_album_captured_idx
  on public.photos (album_id, captured_at desc);
create index photos_album_sha256_idx
  on public.photos (album_id, sha256);

alter table public.albums
  add constraint albums_cover_photo_id_fkey
  foreign key (cover_photo_id) references public.photos (id) on delete set null;

-- ---------------------------------------------------------------------
-- upload_jobs
-- ---------------------------------------------------------------------

create table public.upload_jobs (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  client_upload_id text not null,
  filename text not null,
  expected_size bigint not null,
  received_size bigint not null default 0,
  status text not null default 'pending' check (
    status in ('pending', 'uploading', 'completed', 'failed', 'expired')
  ),
  drive_session_uri_encrypted text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (album_id, user_id, client_upload_id)
);

create index upload_jobs_user_id_idx on public.upload_jobs (user_id);

create trigger set_upload_jobs_updated_at
  before update on public.upload_jobs
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- audit_logs
-- ---------------------------------------------------------------------

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users (id) on delete set null,
  album_id uuid references public.albums (id) on delete set null,
  photo_id uuid references public.photos (id) on delete set null,
  action text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_album_id_idx on public.audit_logs (album_id);
create index audit_logs_created_at_idx on public.audit_logs (created_at desc);

-- =====================================================================
-- 0002_profile_provisioning.sql
-- =====================================================================

-- LiveGallery: criação automática de "profiles" para novos utilizadores
-- Google (administradores/editores). Utilizadores anónimos (convidados)
-- ficam de fora — não têm nem precisam de uma linha em "profiles".
--
-- O papel ("role") é sempre criado como 'editor'. A promoção a 'admin' é
-- uma ação deliberada e fora deste trigger (ver docs/decisions/0002).

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;

  insert into public.profiles (id, email, display_name, avatar_url, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url',
    'editor'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- 0003_row_level_security.sql
-- =====================================================================

-- LiveGallery: Row Level Security (CLAUDE.md secção 8).
--
-- Convenções gerais:
--   * `authenticated` cobre tanto administradores/editores (login Google)
--     como convidados (anonymous sign-in do Supabase) — o Supabase mapeia
--     ambos para o papel `authenticated`, distinguindo-os apenas pelo
--     claim `is_anonymous` dentro do JWT. O papel `anon` só se aplica a
--     pedidos sem qualquer sessão, o que a aplicação nunca usa para dados
--     de álbuns/fotografias (a sessão anónima é sempre criada antes).
--   * Escritas em `photos`, `album_sessions` e `audit_logs` acontecem
--     sempre através de Route Handlers com a service role (que ignora
--     RLS) — por isso estas tabelas não têm políticas de INSERT/UPDATE
--     para `authenticated`.
--   * Cada política de administrador confirma o papel 'admin' consultando
--     a própria linha de `profiles` do utilizador autenticado (nunca a
--     de outro utilizador), pelo que não é necessária nenhuma função
--     SECURITY DEFINER adicional.

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (id = auth.uid());

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Apenas nome e avatar são editáveis pelo próprio utilizador; "role" e
-- "email" só podem ser alterados pela service role (RLS não impede
-- colunas específicas, por isso restringimos ao nível de privilégios).
revoke update on public.profiles from authenticated;
grant select, update (display_name, avatar_url) on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- google_connections
-- ---------------------------------------------------------------------

alter table public.google_connections enable row level security;

create policy "google_connections_owner_admin_all"
  on public.google_connections for all
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

grant select, insert, update, delete on public.google_connections to authenticated;

-- ---------------------------------------------------------------------
-- albums
-- ---------------------------------------------------------------------

alter table public.albums enable row level security;

create policy "albums_owner_admin_all"
  on public.albums for all
  to authenticated
  using (
    owner_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  )
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

create policy "albums_select_via_session"
  on public.albums for select
  to authenticated
  using (
    exists (
      select 1 from public.album_sessions s
      where s.album_id = albums.id
        and s.user_id = auth.uid()
        and s.expires_at > now()
    )
  );

grant select, insert, update, delete on public.albums to authenticated;

-- ---------------------------------------------------------------------
-- album_share_links (nunca acessível a convidados — só o dono do álbum)
-- ---------------------------------------------------------------------

alter table public.album_share_links enable row level security;

create policy "album_share_links_owner_admin_all"
  on public.album_share_links for all
  to authenticated
  using (
    exists (
      select 1 from public.albums a
      join public.profiles p on p.id = a.owner_id
      where a.id = album_share_links.album_id
        and a.owner_id = auth.uid()
        and p.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.albums a
      join public.profiles p on p.id = a.owner_id
      where a.id = album_share_links.album_id
        and a.owner_id = auth.uid()
        and p.role = 'admin'
    )
  );

grant select, insert, update, delete on public.album_share_links to authenticated;

-- ---------------------------------------------------------------------
-- album_sessions (criadas apenas pela service role via Route Handler)
-- ---------------------------------------------------------------------

alter table public.album_sessions enable row level security;

create policy "album_sessions_select_own"
  on public.album_sessions for select
  to authenticated
  using (user_id = auth.uid());

grant select on public.album_sessions to authenticated;

-- ---------------------------------------------------------------------
-- photos (escritas sempre pela service role; leitura conforme estado)
-- ---------------------------------------------------------------------

alter table public.photos enable row level security;

create policy "photos_select_owner"
  on public.photos for select
  to authenticated
  using (
    exists (
      select 1 from public.albums a
      where a.id = photos.album_id and a.owner_id = auth.uid()
    )
  );

create policy "photos_select_visible_via_session"
  on public.photos for select
  to authenticated
  using (
    exists (
      select 1 from public.album_sessions s
      where s.album_id = photos.album_id
        and s.user_id = auth.uid()
        and s.expires_at > now()
        and (
          photos.status = 'ready'
          or (photos.status = 'pending_review' and 'moderate' = any (s.permissions))
        )
    )
  );

grant select on public.photos to authenticated;

-- ---------------------------------------------------------------------
-- upload_jobs (apenas leitura do próprio job, para acompanhar progresso)
-- ---------------------------------------------------------------------

alter table public.upload_jobs enable row level security;

create policy "upload_jobs_select_own"
  on public.upload_jobs for select
  to authenticated
  using (user_id = auth.uid());

grant select on public.upload_jobs to authenticated;

-- ---------------------------------------------------------------------
-- audit_logs (sem acesso de cliente; só a service role, que ignora RLS)
-- ---------------------------------------------------------------------

alter table public.audit_logs enable row level security;

-- =====================================================================
-- 0004_storage.sql
-- =====================================================================

-- LiveGallery: bucket privado para previews/thumbnails derivados.
-- Os originais ficam no Google Drive; este bucket nunca é público e só é
-- lido através de signed URLs de curta duração geradas pela service role.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'photo-previews',
  'photo-previews',
  false,
  10485760, -- 10 MB: generoso para um preview/thumbnail WebP
  array['image/webp', 'image/jpeg']
)
on conflict (id) do nothing;

-- Sem políticas de storage.objects para "authenticated"/"anon": o bucket
-- é privado e todo o acesso passa pela service role (signed URLs geradas
-- no servidor), pelo que RLS nega tudo por omissão a outros papéis.

-- =====================================================================
-- 0005_realtime.sql
-- =====================================================================

-- LiveGallery: Supabase Realtime em "photos" (secção 11).
--
-- A publicação "supabase_realtime" existe por omissão num projeto
-- Supabase, mas começa vazia — é preciso adicionar cada tabela
-- explicitamente. Sem isto, `postgres_changes` nunca entrega eventos,
-- mesmo com RLS e subscrição corretas no cliente.
--
-- Eventos "postgres_changes" respeitam RLS: um cliente só recebe um
-- evento se a política de SELECT da tabela (secção 8,
-- "photos_select_owner"/"photos_select_visible_via_session") permitir
-- ver essa linha para o utilizador autenticado da ligação. Não é preciso
-- nenhuma política nova só para o Realtime.

alter publication supabase_realtime add table public.photos;

-- =====================================================================
-- 0006_share_link_encrypted_token.sql
-- =====================================================================

-- LiveGallery: token de partilha recuperável pelo administrador
-- (docs/decisions/0013-link-partilha-recuperavel.md).
--
-- "token_hash" continua a ser o único usado para resolver um link de
-- convidado (comparação por hash, tal como antes) — este par novo é
-- só para o administrador poder voltar a ver/copiar o link já criado,
-- sem precisar de o regenerar. Encriptado com AES-256-GCM
-- (lib/security/encryption.ts), o mesmo mecanismo já usado para o
-- refresh token do Google Drive em google_connections.
--
-- Nulo em linhas antigas (criadas antes desta migração) — esses links
-- continuam a funcionar normalmente para convidados, só não ficam
-- recuperáveis no painel de administração.

alter table public.album_share_links
  add column encrypted_token text,
  add column token_key_version integer;

-- =====================================================================
-- 0007_photos_uploaded_at_index.sql
-- =====================================================================

-- LiveGallery: índice em falta para a ordenação por omissão do painel
-- de administração.
--
-- server/repositories/photos-repository.ts#listForOwner ordena por
-- "uploaded_at" quando sortBy não é indicado (o valor por omissão em
-- server/use-cases/moderation.ts#listPhotosForOwner) — mas só existia
-- índice para (album_id, status, sort_order) e (album_id, captured_at),
-- nunca para (album_id, uploaded_at). Sem este índice, a listagem de
-- fotos no painel de administração (aba "Fotos", ordenação por data de
-- envio) fazia uma pesquisa sequencial em "photos" filtrada por
-- album_id, em vez de usar um índice — sem impacto visível com poucas
-- fotos, mas cada vez mais lento à medida que o álbum cresce.

create index photos_album_uploaded_idx
  on public.photos (album_id, uploaded_at desc);

-- =====================================================================
-- 0008_photos_partial_indexes.sql
-- =====================================================================

-- LiveGallery: índices parciais para as consultas quentes de "photos".
--
-- Praticamente todas as leituras de "photos" filtram por
-- "deleted_at is null" (galeria pública, painel de administração,
-- contagens do dashboard, deteção de duplicados) — mas nenhum dos
-- índices existentes incluía essa condição, por isso o Postgres tinha
-- de percorrer também as linhas já eliminadas antes de as descartar.
--
-- Índices PARCIAIS (com "where deleted_at is null"): além de guiarem
-- melhor estas consultas, ocupam menos espaço do que os equivalentes
-- completos, por só indexarem as linhas que a aplicação realmente lê.
-- Substituem os índices anteriores, que passam a ser redundantes.

-- Galeria pública: paginação por cursor sobre sort_order, filtrada por
-- álbum e estado (server/repositories/photos-repository.ts#listVisibleForAlbum).
create index photos_album_status_sort_active_idx
  on public.photos (album_id, status, sort_order desc)
  where deleted_at is null;

drop index if exists public.photos_album_status_sort_idx;

-- Painel de administração, ordenação por omissão (listForOwner) e
-- "uploads recentes" do dashboard (listRecentForAlbumIds). Substitui o
-- índice criado na migração 0007, que não era parcial.
create index photos_album_uploaded_active_idx
  on public.photos (album_id, uploaded_at desc)
  where deleted_at is null;

drop index if exists public.photos_album_uploaded_idx;

-- Painel de administração, ordenação alternativa por data de captura.
create index photos_album_captured_active_idx
  on public.photos (album_id, captured_at desc)
  where deleted_at is null;

drop index if exists public.photos_album_captured_idx;

-- Deteção de duplicados no envio (findByAlbumAndSha256), que também
-- filtra por deleted_at is null.
create index photos_album_sha256_active_idx
  on public.photos (album_id, sha256)
  where deleted_at is null;

drop index if exists public.photos_album_sha256_idx;

-- =====================================================================
-- 0009_photos_cursor_tiebreak_index.sql
-- =====================================================================

-- Índice alinhado com a paginação por cursor da galeria pública, que
-- passou a desempatar por `id` (docs/decisions/0043).
--
-- Porquê: `photos.sort_order` tem por omissão o relógio em
-- milissegundos, por isso fotografias enviadas no mesmo instante — o
-- que acontece de verdade com dezenas de convidados a enviar ao mesmo
-- tempo — partilham o mesmo valor. A consulta passou a ordenar por
-- (sort_order desc, id desc) e a filtrar pelo par; sem o `id` no
-- índice, o Postgres tinha de ordenar o resultado à parte.
--
-- Substitui `photos_album_status_sort_active_idx` (migração 0008), que
-- fica redundante: um índice com mais colunas à direita serve na mesma
-- as consultas que só usavam as da esquerda.

create index if not exists photos_album_status_sort_id_active_idx
  on public.photos (album_id, status, sort_order desc, id desc)
  where deleted_at is null;

drop index if exists public.photos_album_status_sort_active_idx;

-- =====================================================================
-- Histórico de migrações do Supabase CLI
--
-- É esta tabela que o painel lê para mostrar "LAST MIGRATION" e que o
-- `supabase db push` consulta para saber o que já foi aplicado. Sem
-- estas linhas, o esquema ficava correto na mesma, mas o CLI achava que
-- nada tinha sido aplicado.
-- =====================================================================

create schema if not exists supabase_migrations;

create table if not exists supabase_migrations.schema_migrations (
  version text primary key,
  statements text[],
  name text
);

insert into supabase_migrations.schema_migrations (version, name)
values
  ('0001', 'initial_schema'),
  ('0002', 'profile_provisioning'),
  ('0003', 'row_level_security'),
  ('0004', 'storage'),
  ('0005', 'realtime'),
  ('0006', 'share_link_encrypted_token'),
  ('0007', 'photos_uploaded_at_index'),
  ('0008', 'photos_partial_indexes'),
  ('0009', 'photos_cursor_tiebreak_index')
on conflict (version) do nothing;
