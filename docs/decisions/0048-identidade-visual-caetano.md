# 0048 — Adotar a identidade visual Caetano

Data: 2026-09-15

## Contexto

O tema até aqui era pêssego/terracota com Playfair Display nos títulos,
derivado de um convite de casamento de referência (ADR 0011). Com o
projeto a passar a ser uma aplicação da Caetano, passa a valer o Manual
de Identidade Caetano (Brand Book, abril 2026).

## Decisão

Todos os valores vêm da secção 04 do manual (códigos digitais RGB) ou
são tints publicados na mesma tabela. Não foi inventada nenhuma cor.

### Cores

| Papel na interface       | Cor do manual                | Valor                                      |
| ------------------------ | ---------------------------- | ------------------------------------------ |
| `brand-600` (botões)     | azul profundo (principal)    | `#002E5D`                                  |
| `brand-500`–`brand-200`  | tints do azul profundo       | `#33587D`, `#66829E`, `#99ABBE`, `#CCD5DF` |
| `accent`                 | azul cyan (secundária)       | `#00AEEF`                                  |
| `surface`                | ultra branco                 | `#FFFFFF`                                  |
| `surface-muted`/`border` | tints do cinza médio         | `#EBEFF1`, `#D7DFE3`                       |
| `success`                | verde eco, escurecido        | `#358364`                                  |
| `warning`                | laranja dinâmico, escurecido | `#A16A1F`                                  |

Três desvios, todos por acessibilidade (secção 17 do `CLAUDE.md`,
WCAG 2.2 AA) e nenhum por gosto:

1. **`success` e `warning` são versões escurecidas.** O verde eco
   (`#49B489`) e o laranja dinâmico (`#FFA931`) do manual são usados na
   interface como TEXTO (`text-success`, `text-warning`), e sobre fundo
   claro dão 2.6:1 e 1.9:1 — ilegíveis. Escurecidos mantêm a matiz e
   passam a 4.6:1. No modo escuro usam-se os tints claros do próprio
   manual (`#92D2B8`, `#FFCB83`), que aí dão 8.7:1 e 10.2:1.
2. **`danger` fica fora da paleta da marca.** O manual não tem vermelho.
   Uma ação destrutiva precisa de um, e não há substituto de marca.
3. **O azul cyan nunca é fundo de texto.** Com texto branco dá 2.5:1.
   Fica reservado a superfícies sem texto — a barra de progresso do
   envio, que assenta sobre o escurecimento da miniatura.

### Modo escuro

O azul profundo desaparece contra um fundo escuro: como fundo de botão
sobre superfície escura dava 1.9:1, muito abaixo dos 3:1 que o WCAG
1.4.11 pede a um componente. O tom interativo desloca-se para o azul
cyan até `#0078B2`, o ponto onde ainda sustenta texto branco (4.9:1) e
já se destaca do fundo (3.6:1). Há uma janela estreita para isto: acima
perde o texto branco, abaixo perde o fundo.

Os fundos e superfícies do modo escuro passam a ser escurecimentos do
azul profundo, não cinzentos neutros.

### Tipografia

Montserrat (secção 03.1) substitui a dupla Geist + Playfair Display. O
manual tem uma tipografia só, por isso títulos e texto corrido passam a
distinguir-se pelo peso e não pela família: a classe `font-serif` foi
renomeada para `font-display`, apontando também a Montserrat, para que
trocar por uma display licenciada no futuro seja uma linha.

Carregada como fonte variável em vez dos três pesos nomeados no manual
(Light/Regular/Bold): a interface já usa 500 e 600 em vários sítios, e
sem eles o browser sintetizava-os.

### Texto

`--foreground` é `#0b1824` — azul profundo escurecido, não preto. O tom
exato é ditado pela acessibilidade: a interface usa `text-foreground/60`
em 24 sítios e, a 60% sobre superfície clara, o azul profundo puro dava
4.35:1. Foi o axe a apanhá-lo na suíte E2E, não uma revisão à vista.

### Logótipo

**Não foi aplicado.** O manual (secção 03) é explícito: o lettering é um
desenho autoral, não tem fonte associada e "não deve ser substituído por
qualquer fonte similar, devendo ser usado apenas o ficheiro oficial da
marca". Sem esse ficheiro, reproduzi-lo seria violar o manual. O
cabeçalho mantém o nome do produto em texto.

## Verificação

17 pares de cor verificados por cálculo (fundo/texto em ambos os modos,
incluindo estados e o botão flutuante): todos conformes, contra os
mínimos de 4.5:1 para texto e 3:1 para componentes.

`pnpm check` (lint + typecheck + format + 306 testes) e `pnpm build` a
passar. A suíte E2E (21 testes), que inclui verificação automática de
acessibilidade com `@axe-core/playwright` nas páginas pública, inicial e
de login, passa sem violações sérias.

## Limitações conhecidas

- O logótipo Caetano continua por aplicar, à espera do ficheiro oficial.
- O modo escuro não é coberto pelos testes do axe (a suíte corre no
  esquema claro); os valores foram verificados por cálculo.
- `text-foreground/50` num contador do painel de administração dá 3.5:1.
  É anterior a esta mudança e está fora das páginas cobertas pelo axe,
  mas continua abaixo de AA — corrigir subindo esse caso para `/60`.
