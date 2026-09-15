-- =====================================================================
-- LiveGallery — migrações pendentes em produção (0006 a 0011)
--
-- COMO USAR: abrir o painel do Supabase → SQL Editor → colar isto tudo
-- → Run. Demora menos de um segundo num álbum desta dimensão.
--
-- Seguro de correr mais do que uma vez, e seguro sem saber ao certo o
-- que já foi aplicado: cada instrução usa "if not exists"/"if exists",
-- por isso o que já existir é simplesmente ignorado, sem erro.
--
-- Corresponde ao estado final das migrações 0006 a 0011 do
-- repositório. A 0007 não aparece aqui porque a 0008 substitui o índice
-- que ela criava, e o índice de ordenação da 0008 aparece já na forma
-- final que a 0009 lhe deu — criá-los primeiro só para os apagar a
-- seguir seria trabalho desperdiçado. O resultado final é exatamente o
-- mesmo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0006 — Link de partilha recuperável pelo administrador
--
-- Sem isto, criar um link continua a funcionar, mas o link deixa de
-- poder ser reexibido/copiado mais tarde no painel de administração
-- (docs/decisions/0013). Colunas anuláveis: nada a preencher depois.
-- ---------------------------------------------------------------------

alter table public.album_share_links
  add column if not exists encrypted_token text,
  add column if not exists token_key_version integer;

-- ---------------------------------------------------------------------
-- 0008 + 0009 — Índices parciais de "photos" (inclui o objetivo da 0007)
--
-- Praticamente todas as leituras de "photos" filtram por
-- "deleted_at is null", mas nenhum índice cobria essa condição. Estes
-- são parciais: mais seletivos e mais pequenos, por só indexarem as
-- linhas que a aplicação lê (docs/decisions/0029).
--
-- Cada "drop index" remove o equivalente não-parcial, que passa a ser
-- redundante — inclui "photos_album_uploaded_idx" da 0007, caso já
-- tenha chegado a ser criado.
-- ---------------------------------------------------------------------

-- Galeria pública: paginação por cursor sobre (sort_order, id). O "id"
-- no fim é o desempate da 0009 (docs/decisions/0043): fotografias
-- enviadas no mesmo milissegundo partilham o mesmo "sort_order", e sem
-- ele o Postgres tinha de ordenar o resultado à parte.
create index if not exists photos_album_status_sort_id_active_idx
  on public.photos (album_id, status, sort_order desc, id desc)
  where deleted_at is null;

drop index if exists public.photos_album_status_sort_idx;
drop index if exists public.photos_album_status_sort_active_idx;

-- Painel de administração (ordenação por omissão) e "uploads recentes".
create index if not exists photos_album_uploaded_active_idx
  on public.photos (album_id, uploaded_at desc)
  where deleted_at is null;

drop index if exists public.photos_album_uploaded_idx;

-- Painel de administração, ordenação por data de captura.
create index if not exists photos_album_captured_active_idx
  on public.photos (album_id, captured_at desc)
  where deleted_at is null;

drop index if exists public.photos_album_captured_idx;

-- Deteção de duplicados no envio (findByAlbumAndSha256).
create index if not exists photos_album_sha256_active_idx
  on public.photos (album_id, sha256)
  where deleted_at is null;

drop index if exists public.photos_album_sha256_idx;

-- ---------------------------------------------------------------------
-- 0010 — Legenda obrigatória por link de partilha
--
-- Sem isto, o código que exige legendas não arranca: ao resolver um
-- link, o servidor grava uma sessão com `require_caption`, e uma coluna
-- em falta faz falhar a abertura do álbum para QUALQUER convidado — não
-- só nos links com legenda obrigatória. É por isso a migração mais
-- urgente deste ficheiro se o código novo já estiver em produção.
--
-- Todas as colunas têm valor por omissão ou são anuláveis: links,
-- sessões e fotografias que já existem mantêm o comportamento atual
-- (docs/decisions/0049).
-- ---------------------------------------------------------------------

alter table public.album_share_links
  add column if not exists require_caption boolean not null default false;

alter table public.album_sessions
  add column if not exists require_caption boolean not null default false;

alter table public.photos
  add column if not exists caption text;

-- ---------------------------------------------------------------------
-- 0011 — "download" passa a ser uma permissão do link de partilha
--
-- A restrição antiga só aceitava 'view', 'upload' e 'moderate', por
-- isso tem de ser substituída antes de o código novo poder gravar um
-- link com transferência.
--
-- ATENÇÃO: os links que já existem ficam SEM transferência a partir do
-- momento em que o código novo entrar, mesmo que o álbum a tenha
-- ativada — eles têm '{view}' ou '{view,upload}'. É o comportamento
-- pretendido (por omissão não se transfere); para repor a
-- transferência num link antigo, cria-se um link novo com a opção
-- marcada.
--
-- Não há perda de dados: só se alarga o que a restrição aceita.
-- ---------------------------------------------------------------------

alter table public.album_share_links
  drop constraint if exists album_share_links_permissions_check;

alter table public.album_share_links
  add constraint album_share_links_permissions_check
  check (permissions <@ array['view', 'upload', 'moderate', 'download']::text[]);

alter table public.album_sessions
  drop constraint if exists album_sessions_permissions_check;

alter table public.album_sessions
  add constraint album_sessions_permissions_check
  check (permissions <@ array['view', 'upload', 'moderate', 'download']::text[]);

-- =====================================================================
-- CONFIRMAR QUE CORREU BEM
-- Correr isto a seguir; deve devolver 9 linhas (5 colunas + 4 índices).
-- =====================================================================

-- select 'coluna: ' || table_name || '.' || column_name as resultado
--   from information_schema.columns
--  where table_schema = 'public'
--    and (
--      (table_name = 'album_share_links'
--       and column_name in ('encrypted_token', 'token_key_version',
--                           'require_caption'))
--      or (table_name = 'album_sessions' and column_name = 'require_caption')
--      or (table_name = 'photos' and column_name = 'caption')
--    )
-- union all
-- select 'índice: ' || indexname
--   from pg_indexes
--  where schemaname = 'public'
--    and indexname like 'photos_album_%_active_idx'
--  order by 1;
