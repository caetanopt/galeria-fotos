"use client";

import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { useWindowVirtualizer } from "@tanstack/react-virtual";
import type { PublicPhoto } from "@/server/use-cases/photos";
import { PhotoTile } from "./photo-tile";

/** `gap-0.5` (0.125rem) na grelha CSS — usado tanto para estimar a
 * largura de cada coluna (folga entre colunas) como a altura de cada
 * linha (folga entre linhas, via `pb-0.5` abaixo) antes da primeira
 * medição real (ver `measureElement`). */
const GRID_GAP_PX = 2;
/** `aspect-square` em `photo-tile.tsx`: altura = largura. */
const HEIGHT_OVER_WIDTH = 1;

/** Espelha os pontos de quebra do Tailwind usados na grelha
 * (`grid-cols-3 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6
 * xl:grid-cols-7 2xl:grid-cols-8`) — para agrupar as fotografias em
 * linhas com o mesmo número de colunas que a grelha CSS desenharia.
 *
 * Tem MESMO de andar a par da grelha simples: se divergirem, os álbuns
 * grandes (acima de `VIRTUALIZE_THRESHOLD`) passam a agrupar as
 * fotografias em linhas de um tamanho e a desenhá-las noutro, e a
 * grelha fica com buracos. */
function getColumnCount(width: number): number {
  if (width >= 1536) return 8;
  if (width >= 1280) return 7;
  if (width >= 1024) return 6;
  if (width >= 768) return 5;
  if (width >= 640) return 4;
  return 3;
}

function useColumnCount(): number {
  const [columns, setColumns] = useState(() =>
    typeof window === "undefined" ? 3 : getColumnCount(window.innerWidth),
  );

  useEffect(() => {
    function handleResize() {
      setColumns(getColumnCount(window.innerWidth));
    }
    handleResize();
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  return columns;
}

/**
 * Grelha virtualizada por linhas (secção 16 do CLAUDE.md: "virtualizar
 * a grelha quando o número de fotografias justificar") — só chegam a
 * montar-se as linhas visíveis, mais uma margem de segurança
 * (`overscan`), em vez de todas as fotografias do álbum de uma vez.
 * Reservada para álbuns grandes (ver `VIRTUALIZE_THRESHOLD` em
 * `photo-grid.tsx`); álbuns normais continuam a usar a grelha simples,
 * mais fácil de percorrer e testar.
 *
 * Virtualiza por linha, não por fotografia individual, para poder
 * continuar a usar a mesma grelha CSS responsiva (`display: grid`)
 * dentro de cada linha — `useColumnCount` só existe para agrupar as
 * fotografias em linhas do tamanho certo antes de as passar ao
 * virtualizador; quem decide onde cada fotografia cai dentro da linha
 * continua a ser o CSS.
 */
export function VirtualizedPhotoGrid({
  photos,
  onOpen,
}: {
  photos: PublicPhoto[];
  onOpen: (photoId: string) => void;
}) {
  const columns = useColumnCount();
  const containerRef = useRef<HTMLDivElement>(null);
  const [scrollMargin, setScrollMargin] = useState(0);
  const [containerWidth, setContainerWidth] = useState(0);

  const rows = useMemo(() => {
    const chunks: PublicPhoto[][] = [];
    for (let i = 0; i < photos.length; i += columns) {
      chunks.push(photos.slice(i, i + columns));
    }
    return chunks;
  }, [photos, columns]);

  // + GRID_GAP_PX: cada linha reserva também o espaço da folga vertical
  // a seguir a ela (ver `pb-0.5` abaixo) — sem isto, a estimativa inicial
  // (antes da primeira medição real) empilhava as linhas coladas.
  //
  // A largura usada é a do PRÓPRIO contentor, não a da janela: desde
  // que a grelha ganhou um teto (`max-w-gallery`), num monitor largo as
  // duas deixaram de coincidir, e estimar pela janela reservava altura
  // a mais em cada linha — a barra de scroll ficava maior do que a
  // página até as medições reais a corrigirem.
  const estimatedRowHeight = useMemo(() => {
    const fallbackWidth =
      typeof window === "undefined" ? 360 : window.innerWidth;
    const width = containerWidth || fallbackWidth;
    const columnWidth = (width - (columns - 1) * GRID_GAP_PX) / columns;
    return columnWidth * HEIGHT_OVER_WIDTH + GRID_GAP_PX;
  }, [columns, containerWidth]);

  // A grelha não começa no topo da janela (cabeçalho, botão de
  // apresentação, etc. vêm antes) — o virtualizador de janela precisa
  // de saber esse deslocamento para posicionar as linhas corretamente.
  // A largura é medida ao mesmo tempo, para a estimativa acima.
  useLayoutEffect(() => {
    const node = containerRef.current;
    if (!node) return;

    const measure = () => {
      setScrollMargin(node.offsetTop);
      setContainerWidth(node.clientWidth);
    };
    measure();

    // Guardado: o jsdom dos testes unitários não implementa
    // `ResizeObserver`, e a medição única acima já serve aí.
    if (typeof ResizeObserver === "undefined") return;
    const observer = new ResizeObserver(measure);
    observer.observe(node);
    return () => observer.disconnect();
  }, [columns]);

  const rowVirtualizer = useWindowVirtualizer({
    count: rows.length,
    estimateSize: () => estimatedRowHeight,
    overscan: 3,
    scrollMargin,
  });

  return (
    <div
      ref={containerRef}
      style={{ position: "relative", height: rowVirtualizer.getTotalSize() }}
    >
      {rowVirtualizer.getVirtualItems().map((virtualRow) => {
        const row = rows[virtualRow.index];
        if (!row) return null;
        // `gap-0.5` só separa colunas dentro da própria linha — cada
        // linha é o seu próprio grid de uma única fila, por isso não há
        // "linha seguinte" para o `gap` do CSS Grid criar espaço contra.
        // `pb-0.5` reproduz a mesma folga vertical que a grelha simples
        // tem de origem (era esta folga que desaparecia ao passar as 60
        // fotografias, quando a grelha virtualizada assumia o lugar).
        // Sem `pb` na última linha, para não sobrar uma folga a mais
        // antes do que vem a seguir (sentinela/"Carregar mais").
        const isLastRow = virtualRow.index === rows.length - 1;

        return (
          <div
            key={virtualRow.key}
            ref={rowVirtualizer.measureElement}
            data-index={virtualRow.index}
            className={`absolute top-0 left-0 grid w-full grid-cols-3 gap-0.5 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6 xl:grid-cols-7 2xl:grid-cols-8 ${isLastRow ? "" : "pb-0.5"}`}
            style={{
              transform: `translateY(${virtualRow.start - scrollMargin}px)`,
            }}
          >
            {row.map((photo) => (
              <PhotoTile
                key={photo.id}
                photo={photo}
                onOpen={onOpen}
                // Só a primeira linha: nas restantes, o virtualizador já
                // só monta o que está perto de ser visto.
                priority={virtualRow.index === 0}
              />
            ))}
          </div>
        );
      })}
    </div>
  );
}
