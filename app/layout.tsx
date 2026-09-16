import type { Metadata, Viewport } from "next";
import { Montserrat } from "next/font/google";
import { Providers } from "./providers";
import "./globals.css";

// Tipografia única da marca (Manual de Identidade Caetano, secção 03.1):
// "sans-serif contemporânea, com linhas geométricas equilibradas". O
// manual indica Light/Regular/Bold; carregamos a variável para que os
// pesos intermédios já usados na interface (500/600) rendam certo em vez
// de serem sintetizados pelo browser.
//
// Substitui a dupla Geist + Playfair Display do tema anterior: a marca
// não tem serifa, e o manual é explícito em ter uma só família.
const montserrat = Montserrat({
  variable: "--font-montserrat",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: {
    default: "LiveGallery",
    template: "%s · LiveGallery",
  },
  description:
    "Galerias de fotografias de eventos, partilhadas por link e atualizadas em tempo real.",
  // Nada nesta aplicação deve aparecer em motores de busca. Vale para o
  // site todo, não só para a página inicial: os álbuns são partilhados
  // por links não listados (secção 6.3), e um `/a/<token>` indexado
  // tornaria público um álbum que era para ser só de quem tem o link.
  robots: { index: false, follow: false },
};

// viewportFit "cover" + os utilitários de safe-area em globals.css
// deixam a grelha e a barra de ações desenharem-se até às bordas em
// ecrãs com notch/ilha dinâmica, sem conteúdo escondido atrás deles
// (uso predominante em telemóvel — secção 10 do CLAUDE.md).
export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: [
    // Acompanham --background em globals.css (paleta Caetano, ADR 0048).
    { media: "(prefers-color-scheme: light)", color: "#f4f8fb" },
    { media: "(prefers-color-scheme: dark)", color: "#071a2e" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="pt-PT"
      data-scroll-behavior="smooth"
      className={`${montserrat.variable} h-full antialiased`}
    >
      <body className="bg-background text-foreground flex min-h-full flex-col">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
