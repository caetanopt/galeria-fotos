import Link from "next/link";

/**
 * Porta de entrada do domínio. Não é uma página de apresentação do
 * produto: nada na aplicação liga para aqui, os álbuns são não listados
 * e o uso é interno, por isso não há ninguém para convencer.
 *
 * Serve duas chegadas, e só essas:
 *
 * 1. O administrador que escreveu o domínio em vez de ir a /admin.
 * 2. Quem ouviu o domínio mas não recebeu o link do álbum — o caso que
 *    antes ficava a olhar para um rótulo "Em construção" sem perceber
 *    que precisava do link. Os convidados chegam sempre por
 *    `/a/<token>`; esta página nunca lhes dá acesso a nada.
 */
export default function Home() {
  return (
    <main className="mx-auto flex w-full max-w-xl flex-1 flex-col items-center justify-center gap-10 px-6 py-24 text-center">
      <div className="flex flex-col items-center gap-4">
        <p className="text-brand-600 text-xs font-bold tracking-[0.25em] uppercase">
          Caetano
        </p>
        <h1 className="text-foreground font-display text-4xl font-bold tracking-tight sm:text-5xl">
          LiveGallery
        </h1>
        <p className="text-foreground/70 text-lg text-balance">
          Galerias de fotografias de eventos, partilhadas por link e atualizadas
          em tempo real.
        </p>
      </div>

      <Link
        href="/admin"
        className="bg-brand-600 hover:bg-brand-700 rounded-full px-6 py-3 text-sm font-semibold text-white transition-colors"
      >
        Entrar na administração
      </Link>

      <p className="border-border text-foreground/60 max-w-md border-t pt-8 text-sm text-balance">
        Recebeu um link para um álbum? Abra-o diretamente — esta página não dá
        acesso a nenhum álbum.
      </p>
    </main>
  );
}
