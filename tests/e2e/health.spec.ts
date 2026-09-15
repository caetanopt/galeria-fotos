import { expect, test } from "@playwright/test";

test("a página inicial carrega e mostra o nome do produto", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/LiveGallery/);
});

test("a página inicial encaminha o administrador e explica-se a quem não tem link", async ({
  page,
}) => {
  await page.goto("/");

  await expect(
    page.getByRole("link", { name: "Entrar na administração" }),
  ).toHaveAttribute("href", "/admin");

  // O caso que justifica esta página existir: quem chega sem link tem
  // de perceber que é aqui que não vai encontrar o álbum.
  await expect(page.getByText("Recebeu um link para um álbum?")).toBeVisible();
});

test("nenhuma página é indexável por motores de busca", async ({ page }) => {
  // Um álbum é partilhado por link não listado: indexá-lo tornava-o
  // público. A regra está no layout raiz, por isso vale para tudo.
  await page.goto("/");
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute(
    "content",
    /noindex/,
  );
});

test("o endpoint de saúde responde com sucesso", async ({ request }) => {
  const response = await request.get("/api/health");
  expect(response.ok()).toBeTruthy();

  const body = await response.json();
  expect(body.data.status).toBe("ok");
});
