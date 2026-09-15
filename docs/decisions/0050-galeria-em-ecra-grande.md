# 0050 — A galeria deixa de ser uma página de telemóvel esticada

Data: 2026-09-15

## Contexto

A galeria pública foi desenhada de margem a margem para telemóvel — e
funciona bem aí. Num monitor, nada tinha largura máxima: os mesmos
valores eram simplesmente esticados até 1900px.

Medido num ecrã de 1920×1080, antes desta alteração:

- a grelha parava em `lg:grid-cols-6`, o que dava miniaturas de **318px**
  (130px num telemóvel) e apenas 12 fotografias por ecrã;
- a lightbox prendia a fotografia a **576px** de largura (`max-w-xl`) —
  clicar numa miniatura abria uma imagem mais pequena do que o preview,
  com o resto do ecrã vazio;
- o cartão do título por cima da capa esticava ~1850px para conter um
  título centrado e uma data;
- o botão flutuante de envio ficava ao centro, por cima das fotografias
  do meio da grelha, e obrigava a 9rem de espaço morto no fim da página;
- as miniaturas não respondiam ao rato (só tinham foco por teclado);
- não havia arrastar e largar, que a secção 10.3 do `CLAUDE.md` pede.

## Decisões

### 1. Teto de largura e mais colunas

Novo token `--container-gallery` (1600px, usado como `max-w-gallery`),
aplicado à barra de controlos e à grelha, com `xl:grid-cols-7` e
`2xl:grid-cols-8`. Miniaturas de ~200px, perto do que já se vê num
portátil, e ~32 fotografias por ecrã em vez de 12.

`getColumnCount()` na grelha virtualizada tem de espelhar exatamente os
mesmos pontos de quebra — se divergirem, os álbuns acima de 60
fotografias agrupam as linhas com um número de colunas e desenham-nas
com outro. A estimativa de altura de linha passou também a usar a
largura do próprio contentor em vez da janela, que deixaram de
coincidir.

### 2. A lightbox usa o ecrã

`max-w-xl` era um teto absoluto. Passa a `lg:h-[86%] lg:w-[64%]
lg:max-w-[1400px]`: ~1230px de largura num monitor de 1920px. As
fotografias vizinhas continuam a espreitar, porque o deslocamento delas
é relativo à largura do slide.

### 3. A capa acompanha a janela

`sm:h-[38vh]` com mínimo de 18rem e máximo de 26rem, em vez de 384px
fixos. Encolhe nos portáteis baixos, onde o espaço vertical é escasso,
sem ficar perdida nos monitores grandes.

Uma proporção fixa (`aspect-[21/9]`) foi tentada primeiro e **não
servia**: acima de ~1030px de largura o teto de altura passava sempre à
frente e o resultado era idêntico ao valor fixo que se queria
substituir. Só se percebeu por captura de ecrã real, não pela leitura
do código.

O telemóvel mantém a altura fixa: aí `vh` compete com a barra de
endereço do browser, que aparece e desaparece com o scroll.

### 4. O envio sai de cima da galeria

A partir de `lg`, o grupo flutuante encosta ao canto inferior direito.
O "voltar ao topo" muda para o canto oposto: a fila de miniaturas cresce
para cima a partir do botão de envio, e uma folga fixa não chegaria para
garantir que não se sobrepõem. A folga no fim da grelha cai de 9rem para
3rem.

Nota sobre alternativas: chegou a ser considerado mover o botão para a
barra de ações no topo da grelha. Isso obrigava a partir o `UploadQueue`
em dois — a barra pertence ao `PhotoGrid`, e todo o estado da fila
(progresso, cancelar, repetir, legendas) vive no `UploadQueue` — a
troco de um ganho que o canto já dá: não tapar as fotografias.

### 5. Arrastar e largar

Listeners na janela inteira, não numa zona desenhada: o alvo deixa de
ser algo em que é preciso acertar. Um contador de profundidade evita
que o aviso pisque quando o cursor cruza fronteiras entre elementos
filhos, e só arrasta que traga `Files` conta — arrastar texto ou uma
ligação é ignorado.

### 6. Resposta ao rato

Escurecimento e lupa no `hover`, além do zoom: o sinal não pode depender
só do movimento (`prefers-reduced-motion`, secção 17) nem só da cor.

## Verificação

Dois testes E2E novos correm a 1920×1080 e fixam os números: 8 colunas,
grelha não mais larga do que 1600px, miniaturas abaixo de 230px, e a
fotografia da lightbox acima de 900px de largura (era 576px fixos).
Três testes unitários cobrem o arrastar e largar, incluindo o caso de um
arrasto sem ficheiros.

`pnpm check` (324 testes) e `pnpm test:e2e` (27) passam. Confirmado
também por captura de ecrã a 1920px, que foi o que apanhou o erro da
proporção descrito na decisão 3.

## Limitações conhecidas

- O fundo da lightbox (`bg-black/20 backdrop-blur-md`) foi pensado para
  um telemóvel, onde quase nada fica à volta da fotografia. Num monitor
  largo, a galeria clara continua a ver-se bem através dele e a
  fotografia destaca-se menos do que devia. Fica por decidir se
  escurecer, porque mexe no aspeto também em telemóvel.
- Nada disto está coberto para o modo escuro nos testes do axe, que
  correm no esquema claro.
