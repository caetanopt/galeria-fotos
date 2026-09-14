# 0047 — Repor os ficheiros de configuração perdidos na importação

Data: 2026-09-14

## Contexto

O repositório foi reimportado para um GitHub novo através de "Add files
via upload" (o carregador da interface web do GitHub), como se vê no
histórico: seis commits, todos com essa mensagem, e nenhum ficheiro
começado por `.` em nenhum deles.

Esse carregador ignora silenciosamente ficheiros e pastas ocultos. Todo
o código, documentação, migrações e testes chegaram intactos — o que se
perdeu foi exatamente a camada de configuração que vive em dot-files, e
que várias partes do projeto assumem existir (o `next.config.ts` refere
o `.npmrc` pelo nome, a `docs/implementation-status.md` dá o
`.env.example` e o `.dockerignore` como concluídos na Fase 0, e a Fase 7
dá o `.github/workflows/ci.yml` como concluído).

Sintomas confirmados neste estado, antes da correção:

- `pnpm format:check` — e portanto `pnpm check` — falhava em três
  ficheiros (`pnpm-lock.yaml`, `CLAUDE.md`, `AGENTS.md`) que o
  `.prettierignore` em falta excluía.
- `pnpm install` voltava a produzir um `node_modules` simbólico
  (`node_modules/sharp` como symlink), porque faltava o `.npmrc` com
  `node-linker=hoisted`. Com essa estrutura, o caminho que o
  `next.config.ts` inclui no rastreio de ficheiros da rota de envio
  (`./node_modules/sharp/node_modules/@img/sharp-libvips-linux-x64/lib/libvips-cpp.so.*`)
  não existe — é a regressão exata do `ERR_DLOPEN_FAILED` do `sharp`
  em produção que a ADR 0012 resolveu.
- Sem `.gitignore`, o `node_modules`, o `.next` e (pior) um `.env.local`
  com segredos reais ficam prontos a ser commitados por engano.
- Sem `.dockerignore`, o `COPY . .` do `Dockerfile` copia o
  `node_modules` da máquina por cima do da imagem e leva os ficheiros
  `.env` para dentro dela.

## Decisão

Repor os ficheiros em falta, reconstruídos a partir do que o próprio
repositório documenta que continham:

| Ficheiro                   | Porquê                                                                   |
| -------------------------- | ------------------------------------------------------------------------ |
| `.npmrc`                   | `node-linker=hoisted` (ADR 0012) — sem isto o `sharp` falha em produção  |
| `.gitignore`               | Impede commitar `node_modules`, `.next` e `.env*` com segredos           |
| `.env.example`             | Secção 20 do `CLAUDE.md`; o `README.md` manda copiá-lo para `.env.local` |
| `.dockerignore`            | Evita que o `COPY . .` leve `node_modules` e `.env*` para a imagem       |
| `.prettierignore`          | Sem ele, `pnpm check` falha                                              |
| `.prettierrc`              | Carrega o `prettier-plugin-tailwindcss` já declarado no `package.json`   |
| `.github/workflows/ci.yml` | CI descrita na Fase 7 e exigida pela secção 21 do `CLAUDE.md`            |

Mudança adicional no `Dockerfile`: a fase `deps` passa a copiar também
o `.npmrc`, para o `node_modules` construído dentro da imagem ter a
mesma estrutura achatada que o `next.config.ts` pressupõe.

O `.env.example` reflete o estado atual do `lib/env.ts`, não só a
secção 20 do `CLAUDE.md` — inclui `MAX_PHOTOS_PER_ALBUM`, `ADMIN_EMAILS`
e `CRON_SECRET`, acrescentados em fases posteriores. O valor de
`MAX_UPLOAD_BYTES` segue o `lib/env.ts` (4 MB, o teto do corpo de um
pedido na Vercel), não os 25 MB da secção 20, com o compromisso
explicado em comentário.

## Verificação

Com os ficheiros repostos e um `pnpm install --frozen-lockfile` de raiz:

- `node_modules/sharp` passou a ser um diretório real e
  `node_modules/sharp/node_modules/@img/sharp-libvips-linux-x64/lib/libvips-cpp.so.8.18.3`
  existe no caminho exato que o `next.config.ts` espera.
- `pnpm check` (lint + typecheck + `format:check` + 299 testes) passa.
- `pnpm build` passa.
- `pnpm test:e2e`: 21 testes a passar.

## Limitações conhecidas

- A CI nunca correu no GitHub Actions a partir deste ficheiro — foi
  escrita a partir da descrição da Fase 7 e dos comandos do
  `package.json`, e cada passo foi validado localmente, mas a primeira
  execução real pode precisar de afinação.
- O `docker build` completo continua por confirmar (mesma limitação da
  ADR 0008/Fase 7).
- Nada aqui substitui a configuração externa que o projeto precisa para
  funcionar de verdade: projeto Supabase com as migrações aplicadas,
  credenciais OAuth da Google e as variáveis de ambiente preenchidas.
  Ver `docs/operations/production-checklist.md`.
