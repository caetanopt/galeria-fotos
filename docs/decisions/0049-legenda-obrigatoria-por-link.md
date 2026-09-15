# 0049 — Legenda obrigatória por link de partilha

Data: 2026-09-15

## Contexto

Quem envia fotografias de várias concessões para o mesmo álbum precisa
de as identificar ("Concessão Porto"), senão o administrador recebe
centenas de imagens indistinguíveis. Mas o mesmo álbum também serve
convívios, onde pedir uma legenda a cada fotografia seria atrito puro.

O pedido foi explícito: acrescentar a opção **na criação do link**, sem
mexer nas opções de envio já existentes — em particular, sem perder o
envio de várias fotografias de uma vez.

## Decisão

### 1. A exigência é do link, não do álbum

Um álbum pode ter dois links: um que exige legenda e outro que não. A
coluna nova é `album_share_links.require_caption`, copiada para
`album_sessions.require_caption` no momento em que o link é resolvido —
tal como já acontece com `permissions`.

**Porque é copiada para a sessão:** `authorizeUpload()` corre duas
vezes por fotografia (iniciar e concluir o envio). Ler o link a cada
uma dessas passagens acrescentava dois round trips à base de dados por
fotografia, num caminho onde o código já evita deliberadamente round
trips (ver ADR 0040). A sessão já é lida nesse ponto; a exigência vem
de borla.

### 2. Não entra em `permissions`

`permissions` é um conjunto de capacidades (`view`, `upload`,
`moderate`), com uma restrição na base de dados que só aceita esses
três valores. Uma legenda obrigatória é uma exigência sobre quem já tem
`upload`, não uma capacidade nova. Metê-la lá obrigava a alterar a
restrição e tornava o significado da coluna ambíguo.

Corolário: `require_caption` só é gravado como `true` quando as
permissões incluem `upload` — num link só de leitura não teria a quem
se aplicar. A resolução do link volta a verificar isto, para o caso de
os envios terem sido desligados no álbum depois de o link ser criado.

### 3. O portão está na fila de envio, não num formulário à parte

Na interface, uma fotografia selecionada passa a um estado novo,
`awaiting_caption`, antes de `queued`. A fila só arranca quando a
legenda existe. Isto preserva exatamente o fluxo atual — escolher
várias fotografias de uma vez, otimização no cliente, três envios
concorrentes — e limita-se a atrasar a entrada na fila.

Para não obrigar a escrever "Concessão Porto" vinte vezes, há um botão
"Aplicar a primeira legenda a todas".

### 4. O servidor não confia no cliente

A legenda viaja no mesmo `multipart/form-data` do ficheiro (campo
`caption`), para não acrescentar um pedido por fotografia. O formato é
validado no Route Handler (`captionSchema`: aparada, máximo 200
caracteres); **se é obrigatória** decide-o `completeUpload` a partir da
sessão, não do pedido — um cliente não contorna a exigência omitindo o
campo. Falta de legenda num link que a exige devolve
`UPLOAD_CAPTION_REQUIRED` (422). Uma legenda só com espaços conta como
vazia.

### 5. Onde a legenda aparece

- **Lightbox**: por cima da linha de metadados e como `alt` da imagem.
  Isto resolve de caminho o texto alternativo configurável que a secção
  17 do `CLAUDE.md` pede; sem legenda, mantém-se a descrição neutra
  ("Fotografia do álbum"), nunca o nome técnico do ficheiro.
- **Moderação**: por cima dos estados, porque é o que identifica a
  fotografia quando a imagem sozinha não chega. Renderizada como texto,
  nunca como HTML (secção 15).

## Consequências

- Migração `0010_required_caption.sql`, aditiva e com valores por
  omissão: links, sessões e fotografias que já existem mantêm o
  comportamento atual, sem alteração nenhuma.
- Sessões criadas antes da migração são recriadas quando a exigência do
  link deixar de bater certo com a sessão em vigor — a comparação em
  `resolveAlbumSession` passou a incluir `require_caption`.
- `photos.caption` fica disponível para uma pesquisa futura por texto,
  mas não foi indexada: o MVP não tem pesquisa (secção 25).

## Alternativas descartadas

- **Exigência ao nível do álbum**: obrigaria a criar álbuns duplicados
  para os dois casos de uso.
- **Legenda pedida depois do envio**: quem envia por telemóvel fecha o
  separador assim que as barras de progresso acabam; as legendas nunca
  chegariam.
- **Um pedido `PATCH` por legenda depois de cada envio**: duplicava o
  número de pedidos e deixava a janela em que uma fotografia existe sem
  a identificação que o link exigia.
