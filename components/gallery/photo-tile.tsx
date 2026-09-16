import type { PublicPhoto } from "@/server/use-cases/photos";

/** Uma miniatura da grelha — partilhada entre a grelha simples e a
 * grelha virtualizada (`virtualized-photo-grid.tsx`), para não
 * duplicar o mesmo botão em dois sítios. */
export function PhotoTile({
  photo,
  onOpen,
  priority = false,
}: {
  photo: PublicPhoto;
  onOpen: (photoId: string) => void;
  /**
   * Para as primeiras miniaturas, as que já estão visíveis quando a
   * galeria abre. `loading="lazy"` faz o browser esperar pelo cálculo
   * do layout antes de sequer começar a descarregar — o que faz sentido
   * para o que está fora do ecrã, mas atrasa precisamente as imagens
   * que dão a sensação de a página ter carregado.
   */
  priority?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={() => onOpen(photo.id)}
      className="group bg-surface-muted focus-visible:ring-brand-600 relative block aspect-square w-full cursor-pointer overflow-hidden focus-visible:z-10 focus-visible:ring-2 focus-visible:ring-inset"
    >
      {photo.thumbnailUrl && (
        // eslint-disable-next-line @next/next/no-img-element -- URL assinado de um domínio de Storage dinâmico (por instalação); ver docs/decisions/0005.
        <img
          src={photo.thumbnailUrl}
          alt="Fotografia do álbum"
          loading={priority ? "eager" : "lazy"}
          fetchPriority={priority ? "high" : "auto"}
          // Descodificar fora da linha principal: com dezenas de
          // miniaturas a chegar ao mesmo tempo, descodificá-las de forma
          // síncrona bloqueia o scroll.
          decoding="async"
          className="absolute inset-0 h-full w-full object-cover transition-transform duration-300 group-hover:scale-[1.06] motion-reduce:transition-none motion-reduce:group-hover:scale-100"
        />
      )}

      {/* Resposta ao rato, que só existe no desktop: sem isto, passar
          por cima de uma miniatura não dava sinal nenhum de que era
          clicável — a grelha só tinha estado de foco por teclado. O
          escurecimento e a lupa entram juntos para o sinal não depender
          só do movimento (secção 17: `prefers-reduced-motion`, e nunca
          só a cor a indicar estado). Escondido do leitor de ecrã: é o
          próprio botão que já anuncia a ação. */}
      <span
        aria-hidden="true"
        className="absolute inset-0 flex items-center justify-center bg-black/0 opacity-0 transition duration-200 group-hover:bg-black/30 group-hover:opacity-100 motion-reduce:transition-none"
      >
        <svg
          viewBox="0 0 20 20"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          className="h-6 w-6 text-white drop-shadow"
        >
          <circle cx="9" cy="9" r="5.5" />
          <path d="M13 13l4 4" />
        </svg>
      </span>
    </button>
  );
}
