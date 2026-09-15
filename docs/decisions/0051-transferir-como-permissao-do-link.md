# 0051 — Transferir passa a ser uma permissão do link de partilha

Data: 2026-09-15

## Contexto

Transferir fotografias era uma decisão do **álbum** (`albums.download_enabled`),
ligada por omissão. Quem recebesse um link — qualquer link — podia
descarregar os originais.

O pedido foi: acrescentar a transferência às opções do link, desligada
por omissão, "para mantermos a mesma lógica das outras opções".

## Decisão

### Entra em `permissions`, ao contrário da legenda obrigatória

A ADR 0049 deixou a legenda obrigatória **fora** do array `permissions`,
com o argumento de que essa coluna é um conjunto de capacidades e uma
legenda obrigatória é uma exigência sobre quem já tem `upload`, não uma
capacidade nova.

Transferir **é** uma capacidade, da mesma família de `view`, `upload` e
`moderate`. O mesmo argumento que manteve a legenda de fora põe a
transferência lá dentro.

Isso traz de borla exatamente o que foi pedido: o valor por omissão da
coluna é `'{view}'`, portanto um link novo nasce sem transferência sem
ser preciso escrever uma linha a dizê-lo. E a caixa aparece sozinha no
formulário, ao lado das outras três, porque a lista é gerada a partir
de `PERMISSION_LABELS`.

### O álbum manda sobre o link

A resolução do link já retirava `upload` quando o álbum tinha os envios
desligados. A regra passa a valer também para `download`, no mesmo
filtro: desligar a transferência no painel do álbum tem de valer para os
links já distribuídos, senão o interruptor não teria efeito sobre eles.

### Duas verificações no servidor, não uma

`getOriginalForViewer` passa a exigir a permissão **na sessão** e
continua a verificar o interruptor do álbum. A segunda não é
redundante: apanha o caso de o álbum ser desligado *depois* de a sessão
ter sido criada, sem ser preciso esperar que ela expire.

A interface deixa de olhar para `album.downloadEnabled` e passa a olhar
para a permissão — que já traz os dois critérios cruzados.

## Consequências

**Os links que já existem perdem a transferência.** Têm `'{view}'` ou
`'{view,upload}'`, portanto a partir do momento em que este código
entrar, quem os tiver deixa de conseguir descarregar — mesmo com o
álbum a permitir. É a consequência pretendida ("por defeito não é
possível"), mas é uma mudança de comportamento para links já
distribuídos. Para repor, cria-se um link novo com a opção marcada.

A migração 0011 substitui a restrição `check` das duas tabelas. Não há
perda de dados: só se alarga o conjunto aceite, e nenhum valor existente
deixa de ser válido.

## Verificação

Contra um PostgreSQL 16 real: confirmado primeiro que o nome gerado
automaticamente pela restrição em linha da 0001 é mesmo
`album_share_links_permissions_check` (se não fosse, o `drop ... if
exists` não apanhava nada e o `add` falhava por nome duplicado); depois
que a migração aplica, volta a aplicar sem erro, passa a aceitar
`'{view,upload,download}'`, continua a recusar um valor inventado, e não
mexe nas linhas que já existiam.

Cinco testes unitários novos: o link sem a permissão não transfere mesmo
com o álbum a permitir; o álbum desligado corta um link que a tinha; e
os dois lados do filtro na resolução. Um teste E2E verifica que o botão
"Transferir" só aparece na lightbox com a permissão.

Dois ficheiros de teste duplicavam a união `"view" | "upload" |
"moderate"` em vez de importarem `AlbumSessionPermission` — foi por isso
que acrescentar uma permissão os partiu. Passam a usar o tipo.

`pnpm check` (329 testes) e `pnpm test:e2e` (28) passam.
