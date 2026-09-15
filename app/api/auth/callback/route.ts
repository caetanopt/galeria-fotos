import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/db/supabase-server";
import { sanitizeRedirectPath } from "@/lib/security/safe-redirect";
import { logger } from "@/lib/observability/logger";

const LOGIN_PATH = "/admin/login";

/**
 * Destino do redirecionamento OAuth do Supabase Auth (login Google do
 * administrador — secção 6.1). Troca o código de autorização por uma
 * sessão e reencaminha para a área administrativa.
 *
 * As duas falhas possíveis são registadas (secção 18): sem isto, um
 * login que falha em produção só se manifesta como
 * `?error=auth_callback_failed` no browser, sem deixar rasto nenhum do
 * motivo — que foi exatamente o que aconteceu na primeira instalação.
 * Nunca registar o código de autorização nem os tokens: só o motivo
 * devolvido pelo Supabase.
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = sanitizeRedirectPath(searchParams.get("next"));

  const failure = NextResponse.redirect(
    `${origin}${LOGIN_PATH}?error=auth_callback_failed`,
  );

  if (!code) {
    // Sem código: o fornecedor recusou antes de chegar aqui. O Supabase
    // reencaminha o motivo em "error"/"error_description" — é o caso de
    // um consentimento negado ou de uma conta fora dos "test users" de
    // um ecrã de consentimento em modo Testing.
    logger.error({
      operation: "auth.callback.missingCode",
      providerError: searchParams.get("error") ?? "(nenhum)",
      providerErrorCode: searchParams.get("error_code") ?? "(nenhum)",
      message:
        searchParams.get("error_description") ??
        "Callback sem código de autorização.",
    });
    return failure;
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    // Causa mais comum: o cookie com o "code verifier" do PKCE não
    // chegou aqui (sessão iniciada noutro browser/separador, cookies
    // bloqueados, ou um código já usado).
    logger.error({
      operation: "auth.callback.exchangeCodeForSession",
      errorCode: error.code ?? "(nenhum)",
      status: error.status ?? 0,
      message: error.message,
    });
    return failure;
  }

  return NextResponse.redirect(`${origin}${next}`);
}
