-- LiveGallery: legenda obrigatória por fotografia, por link de partilha.
--
-- Caso de uso: um link entregue a quem visita concessões precisa que
-- cada fotografia venha identificada ("Concessão Porto"), enquanto o
-- link de um convívio não quer nada disso. A exigência é do LINK, não do
-- álbum — o mesmo álbum pode ter os dois.
--
-- Porque é que isto NÃO entra em "permissions": essa coluna é um
-- conjunto de capacidades ('view', 'upload', 'moderate'), com uma
-- restrição na base de dados que só aceita esses três valores. Uma
-- legenda obrigatória é uma exigência sobre quem já tem 'upload', não
-- uma capacidade nova. Misturar as duas coisas obrigava a alterar a
-- restrição e a tornar o significado da coluna ambíguo.
--
-- Todas as colunas têm valor por omissão: links, sessões e fotografias
-- que já existem mantêm exatamente o comportamento atual.

alter table public.album_share_links
  add column if not exists require_caption boolean not null default false;

-- A sessão copia a exigência do link, tal como já copia as permissões.
-- Sem isto, validar um envio obrigava a ir buscar o link a cada
-- fotografia — e `authorizeUpload` corre duas vezes por fotografia
-- (iniciar e concluir), num caminho onde o código já evita
-- deliberadamente round trips à base de dados.
alter table public.album_sessions
  add column if not exists require_caption boolean not null default false;

-- Texto livre escrito por quem envia. Anulável: a esmagadora maioria
-- das fotografias não tem legenda, e o limite acompanha o que a
-- validação do servidor aceita (lib/validation/upload.ts).
alter table public.photos
  add column if not exists caption text;
