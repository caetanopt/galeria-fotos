import Link from "next/link";
import { getCurrentProfile } from "@/lib/auth/dal";
import { getServerEnv } from "@/lib/env";
import { isAdmin } from "@/lib/auth/admin";
import { CaetanoWordmark } from "@/components/brand/caetano-wordmark";

/**
 * Cabeçalho comum à área administrativa. Antes disto, só o painel
 * inicial tinha ligações: a lista de álbuns, o detalhe de um álbum e as
 * integrações eram becos sem saída — para voltar, só o botão do
 * browser. O "Sair" tinha o mesmo problema, existia num sítio só.
 *
 * PORQUE É CONDICIONAL: a página de login vive neste mesmo segmento de
 * rotas, e mostrar-lhe uma navegação de administração seria oferecer
 * atalhos a quem ainda não entrou. O cabeçalho aparece exatamente
 * quando há sessão de administrador para o usar.
 *
 * Isto não acrescenta um pedido de rede: `getCurrentProfile` está
 * embrulhado no `cache()` do React e as páginas já o chamam através de
 * `requireAdmin()` — no mesmo render, a resposta é reaproveitada.
 *
 * A autorização real continua a ser feita por cada página; este
 * cabeçalho só decide o que desenhar.
 */
export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const profile = await getCurrentProfile();
  const showNav =
    profile !== null &&
    isAdmin({
      email: profile.email,
      role: profile.role,
      adminEmails: getServerEnv().ADMIN_EMAILS,
    });

  return (
    <>
      {showNav && (
        <header className="border-border bg-surface border-b">
          <div className="mx-auto flex w-full max-w-6xl flex-wrap items-center gap-x-6 gap-y-3 px-6 py-3">
            <Link
              href="/admin"
              aria-label="Administração do LiveGallery"
              className="hover:opacity-80"
            >
              <CaetanoWordmark className="text-wordmark h-5 w-auto" />
            </Link>
            <nav aria-label="Administração">
              <ul className="flex flex-wrap items-center gap-x-5 gap-y-2 text-sm">
                <li>
                  <Link
                    href="/admin"
                    className="text-foreground/70 hover:text-foreground transition-colors"
                  >
                    Painel
                  </Link>
                </li>
                <li>
                  <Link
                    href="/admin/albums"
                    className="text-foreground/70 hover:text-foreground transition-colors"
                  >
                    Álbuns
                  </Link>
                </li>
                <li>
                  <Link
                    href="/admin/settings/integrations"
                    className="text-foreground/70 hover:text-foreground transition-colors"
                  >
                    Integrações
                  </Link>
                </li>
              </ul>
            </nav>
            <form action="/api/auth/signout" method="post" className="ms-auto">
              <button
                type="submit"
                className="border-border text-foreground hover:bg-surface-muted rounded-full border px-4 py-1.5 text-sm font-medium transition-colors"
              >
                Sair
              </button>
            </form>
          </div>
        </header>
      )}
      {children}
    </>
  );
}
