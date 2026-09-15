"use client";

import { ApiRequestError } from "@/lib/api/client";
import { formatEventDate } from "@/lib/format-date";
import { UploadQueue } from "@/components/upload/upload-queue";
import { useResolveAlbum } from "./use-resolve-album";
import { PinGate } from "./pin-gate";
import { PhotoGrid } from "./photo-grid";

export function AlbumResolver({ token }: { token: string }) {
  const mutation = useResolveAlbum(token);

  const isPinError =
    mutation.isError &&
    mutation.error instanceof ApiRequestError &&
    (mutation.error.code === "ALBUM_PIN_REQUIRED" ||
      mutation.error.code === "ALBUM_PIN_INVALID");

  if (mutation.isPending || mutation.isIdle) {
    return (
      <main className="flex flex-1 flex-col items-center justify-center gap-3 px-6 py-24 text-center">
        <p className="text-foreground/60 text-sm">A abrir álbum…</p>
      </main>
    );
  }

  if (isPinError) {
    return (
      <PinGate
        onSubmit={(pin) => mutation.mutate(pin)}
        isPending={mutation.isPending}
        error={mutation.error}
      />
    );
  }

  if (mutation.isError) {
    const message =
      mutation.error instanceof ApiRequestError
        ? mutation.error.message
        : "Não foi possível abrir este álbum. Tente novamente.";

    return (
      <main className="flex flex-1 flex-col items-center justify-center gap-3 px-6 py-24 text-center">
        <h1 className="text-foreground font-display text-2xl font-semibold">
          Álbum indisponível
        </h1>
        <p role="alert" className="text-foreground/70 max-w-md text-sm">
          {message}
        </p>
      </main>
    );
  }

  const { album, permissions, requireCaption, isOwner, initialPhotos } =
    mutation.data;
  const canUpload = permissions.includes("upload");

  return (
    <main className="flex flex-1 flex-col">
      {/* Com fotografia de capa, o cabeçalho é de margem a margem (sem
          padding lateral nem largura máxima) — a fotografia é o
          elemento de abertura do álbum e ganha em ocupar o ecrã todo.
          Sem capa, mantém-se o cartão centrado com margens.

          A partir de `sm`, a altura passa a ser uma FRAÇÃO DA JANELA
          com mínimo e máximo, em vez dos 384px fixos de antes. Num
          monitor de 1080px de altura, a capa fixa ocupava mais de um
          terço do ecrã e empurrava a galeria para baixo da dobra —
          via-se a capa e uma linha e meia de fotografias. Ligada à
          altura da janela, encolhe nos portáteis baixos (onde o espaço
          vertical é escasso) sem ficar perdida nos monitores grandes.

          Uma proporção fixa (`aspect-[21/9]`) foi tentada primeiro e
          não servia: acima de ~1030px de largura o teto de altura
          passava sempre à frente, e o resultado era igual ao valor
          fixo que se queria substituir.

          O telemóvel mantém a altura fixa: aí `vh` compete com a barra
          de endereço do browser, que aparece e desaparece com o
          scroll. */}
      <header
        className={
          album.coverPhotoUrl
            ? "safe-top"
            : "px-4 pt-[calc(env(safe-area-inset-top)+1.5rem)] sm:px-6 sm:pt-[calc(env(safe-area-inset-top)+2rem)]"
        }
      >
        {album.coverPhotoUrl ? (
          <div className="relative h-72 w-full sm:h-[38vh] sm:max-h-[26rem] sm:min-h-[18rem]">
            {/* eslint-disable-next-line @next/next/no-img-element -- URL assinado do Supabase Storage, gerado por pedido (secção 5.4); decorativa, o título ao lado já descreve o álbum. */}
            <img
              src={album.coverPhotoUrl}
              alt=""
              // É a maior imagem do ecrã e a primeira que se vê: é ela
              // que determina quando a página "parece" carregada, por
              // isso vai à frente das miniaturas na fila do browser.
              fetchPriority="high"
              decoding="async"
              className="absolute inset-0 h-full w-full object-cover"
            />
            {/* `max-w-3xl` + `mx-auto`: num monitor largo, um cartão de
                margem a margem esticava quase 1900px para conter um
                título centrado e uma data — uma faixa quase toda
                vazia. No telemóvel nada muda, porque o ecrã nunca
                chega ao limite. */}
            <div className="rounded-card border-border/40 bg-surface/60 absolute inset-x-3 bottom-3 mx-auto max-w-3xl border p-5 text-center shadow-lg backdrop-blur-md sm:inset-x-6 sm:bottom-6 sm:p-6">
              <div
                aria-hidden="true"
                className="mb-4 flex items-center justify-center gap-3"
              >
                <span className="bg-brand-600/40 h-px w-8 sm:w-10" />
                <span className="bg-brand-600 h-1.5 w-1.5 rounded-full" />
                <span className="bg-brand-600/40 h-px w-8 sm:w-10" />
              </div>
              <h1 className="text-foreground font-display text-2xl font-semibold text-balance sm:text-3xl">
                {album.title}
              </h1>
              {album.eventStartAt && (
                <p className="text-foreground/70 mt-1 text-xs sm:text-sm">
                  {formatEventDate(album.eventStartAt)}
                </p>
              )}
              {album.description && (
                <p className="text-foreground/80 mx-auto mt-2 max-w-md text-sm text-balance">
                  {album.description}
                </p>
              )}
            </div>
          </div>
        ) : (
          <div className="rounded-card border-border bg-surface mx-auto max-w-2xl border p-8 text-center shadow-md sm:p-10">
            <div
              aria-hidden="true"
              className="mb-5 flex items-center justify-center gap-3"
            >
              <span className="bg-brand-600/40 h-px w-10 sm:w-14" />
              <span className="bg-brand-600 h-1.5 w-1.5 rounded-full" />
              <span className="bg-brand-600/40 h-px w-10 sm:w-14" />
            </div>
            <h1 className="text-foreground font-display text-3xl font-semibold text-balance sm:text-4xl">
              {album.title}
            </h1>
            {album.eventStartAt && (
              <p className="text-foreground/70 mt-1.5 text-xs sm:text-sm">
                {formatEventDate(album.eventStartAt)}
              </p>
            )}
            {album.description && (
              <p className="text-foreground/70 mx-auto mt-3 max-w-md text-sm text-balance">
                {album.description}
              </p>
            )}
          </div>
        )}
      </header>

      {/* A folga no fim da grelha existe para o botão flutuante de
          envio não tapar as últimas fotografias. A partir de `lg` ele
          encosta ao canto, deixa de estar por cima da grelha, e a
          folga pode encolher para quase nada. */}
      <div
        className={`flex flex-1 flex-col ${canUpload ? "pb-36 sm:pb-40 lg:pb-12" : ""}`}
      >
        <PhotoGrid
          albumId={album.id}
          // Da PERMISSÃO do link, não do interruptor do álbum: um
          // álbum com transferências ligadas pode ter um link que as
          // não dá. A resolução já cruza os dois (`resolve-album.ts`),
          // por isso aqui basta a permissão.
          downloadEnabled={permissions.includes("download")}
          isOwner={isOwner}
          initialPhotos={initialPhotos}
        />
      </div>

      {canUpload && (
        <UploadQueue albumId={album.id} requireCaption={requireCaption} />
      )}
    </main>
  );
}
