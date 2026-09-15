-- LiveGallery: "download" passa a ser uma permissão do link de partilha.
--
-- Ao contrário da legenda obrigatória (migração 0010), transferir É uma
-- capacidade — da mesma família de 'view', 'upload' e 'moderate' — por
-- isso entra no array `permissions` em vez de numa coluna à parte. A
-- consequência prática é boa: o valor por omissão da coluna continua a
-- ser '{view}', portanto um link novo nasce sem permissão de
-- transferência sem ser preciso escrever mais nada.
--
-- A restrição existente só aceita os três valores antigos, e é por isso
-- que tem de ser substituída. `<@` continua a ser contenção de
-- conjuntos: qualquer subconjunto dos quatro valores é aceite.
--
-- ATENÇÃO ao efeito nos links que já existem: eles têm '{view}' ou
-- '{view,upload}', logo ficam SEM transferência a partir do momento em
-- que o código novo entrar — mesmo que o álbum a tenha ativada. É a
-- consequência querida ("por defeito não é possível"), mas é uma
-- mudança de comportamento para links já distribuídos. Para repor a
-- transferência num link antigo, cria-se um link novo com a opção
-- marcada.
--
-- Não há perda de dados: só se alarga o que a restrição aceita; nenhum
-- valor existente deixa de ser válido.

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
