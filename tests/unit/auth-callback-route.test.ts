import { beforeEach, describe, expect, it, vi } from "vitest";

const exchangeCodeForSession = vi.fn();
const errorLog = vi.fn();

vi.mock("@/lib/db/supabase-server", () => ({
  createSupabaseServerClient: async () => ({
    auth: { exchangeCodeForSession },
  }),
}));

vi.mock("@/lib/observability/logger", () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: errorLog },
}));

const { GET } = await import("@/app/api/auth/callback/route");

const ORIGIN = "https://exemplo.test";
const FAILURE_URL = `${ORIGIN}/admin/login?error=auth_callback_failed`;

function request(query: string) {
  return new Request(`${ORIGIN}/api/auth/callback${query}`);
}

describe("GET /api/auth/callback", () => {
  beforeEach(() => {
    exchangeCodeForSession.mockReset();
    errorLog.mockReset();
  });

  it("cria a sessão e segue para o destino pedido", async () => {
    exchangeCodeForSession.mockResolvedValue({ error: null });

    const response = await GET(request("?code=abc&next=/admin/albums"));

    expect(exchangeCodeForSession).toHaveBeenCalledWith("abc");
    expect(response.headers.get("location")).toBe(`${ORIGIN}/admin/albums`);
    expect(errorLog).not.toHaveBeenCalled();
  });

  it("regista o motivo quando o fornecedor recusa antes de haver código", async () => {
    const response = await GET(
      request("?error=access_denied&error_description=Conta+sem+acesso"),
    );

    expect(exchangeCodeForSession).not.toHaveBeenCalled();
    expect(response.headers.get("location")).toBe(FAILURE_URL);

    const [fields] = errorLog.mock.calls[0];
    expect(fields.operation).toBe("auth.callback.missingCode");
    expect(fields.providerError).toBe("access_denied");
    expect(fields.message).toBe("Conta sem acesso");
  });

  it("regista o motivo quando a troca do código falha, sem expor o código", async () => {
    exchangeCodeForSession.mockResolvedValue({
      error: { code: "flow_state_not_found", status: 404, message: "boom" },
    });

    const response = await GET(request("?code=um-codigo-secreto"));

    expect(response.headers.get("location")).toBe(FAILURE_URL);

    const [fields] = errorLog.mock.calls[0];
    expect(fields.operation).toBe("auth.callback.exchangeCodeForSession");
    expect(fields.errorCode).toBe("flow_state_not_found");
    expect(fields.status).toBe(404);
    expect(JSON.stringify(fields)).not.toContain("um-codigo-secreto");
  });

  it("não aceita um destino externo vindo do parâmetro next", async () => {
    exchangeCodeForSession.mockResolvedValue({ error: null });

    const response = await GET(
      request("?code=abc&next=https://malicioso.test"),
    );

    expect(response.headers.get("location")).toBe(`${ORIGIN}/admin`);
  });
});
