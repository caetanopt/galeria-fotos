-- =====================================================================
-- LiveGallery — verificar um projeto Supabase depois das migrações
--
-- COMO USAR: painel do Supabase → SQL Editor → colar isto tudo → Run.
-- Só lê; não altera nada.
--
-- Cada bloco devolve uma coluna "estado" que começa por "OK" ou por
-- "FALTA"/"ERRO". Se alguma linha não começar por "OK", a aplicação vai
-- falhar (ou degradar em silêncio, no caso do tempo real).
-- =====================================================================

-- 1. Tabelas da secção 7 + RLS ativo em todas (secção 8).
--    audit_logs com 0 políticas é o esperado: nega tudo aos clientes e
--    só a service role escreve lá.
select
  case
    when count(*) filter (where not relrowsecurity) > 0 then 'ERRO: RLS desligado nalguma tabela'
    when count(*) = 8 then 'OK: 8 tabelas, todas com RLS'
    else 'FALTA: só ' || count(*) || ' das 8 tabelas existem'
  end as estado
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'profiles', 'google_connections', 'albums', 'album_share_links',
    'album_sessions', 'photos', 'upload_jobs', 'audit_logs'
  );

-- 2. Colunas da migração 0006 (link de partilha recuperável).
select
  case when count(*) = 2 then 'OK: album_share_links tem encrypted_token + token_key_version'
       else 'FALTA: migração 0006 não aplicada' end as estado
from information_schema.columns
where table_schema = 'public'
  and table_name = 'album_share_links'
  and column_name in ('encrypted_token', 'token_key_version');

-- 3. Índices parciais de "photos" (migrações 0008 + 0009). O de
--    ordenação tem de ser a versão com desempate por id (0009).
select
  case when count(*) = 4 then 'OK: 4 índices parciais de photos'
       else 'FALTA: só ' || count(*) || ' dos 4 índices (migrações 0008/0009)' end as estado
from pg_indexes
where schemaname = 'public'
  and indexname in (
    'photos_album_status_sort_id_active_idx',
    'photos_album_uploaded_active_idx',
    'photos_album_captured_active_idx',
    'photos_album_sha256_active_idx'
  );

-- 4. Bucket privado de previews (migração 0004). Privado não é um
--    detalhe: os previews são servidos só por signed URLs.
select
  case when count(*) = 0 then 'FALTA: bucket photo-previews não existe (migração 0004)'
       when bool_or(public) then 'ERRO: bucket photo-previews está PÚBLICO'
       else 'OK: bucket photo-previews existe e é privado' end as estado
from storage.buckets
where id = 'photo-previews';

-- 5. Tempo real (migração 0005). Esta é a que falha em silêncio: sem
--    ela a aplicação funciona toda, só as fotografias novas é que não
--    aparecem sozinhas nos outros dispositivos.
select
  case when count(*) = 1 then 'OK: photos está na publicação supabase_realtime'
       else 'FALTA: migração 0005 — o tempo real fica inativo sem erro' end as estado
from pg_publication p
join pg_publication_rel pr on pr.prpubid = p.oid
join pg_class c on c.oid = pr.prrelid
join pg_namespace n on n.oid = c.relnamespace
where p.pubname = 'supabase_realtime'
  and n.nspname = 'public'
  and c.relname = 'photos';

-- 6. Trigger de provisionamento de perfis (migração 0002). Sem ele, um
--    administrador faz login com Google mas nunca ganha uma linha em
--    "profiles" — e fica sem acesso ao painel.
select
  case when count(*) = 1 then 'OK: trigger on_auth_user_created existe'
       else 'FALTA: migração 0002 — o login cria a conta mas não o perfil' end as estado
from pg_trigger
where tgname = 'on_auth_user_created'
  and not tgisinternal;
