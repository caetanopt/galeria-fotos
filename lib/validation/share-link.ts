import { z } from "zod";

export const shareLinkPermissionSchema = z.enum([
  "view",
  "upload",
  "moderate",
  // Transferir É uma capacidade, ao contrário da legenda obrigatória
  // abaixo — por isso vive aqui, e não numa opção à parte (migração
  // 0011). Fica de fora por omissão, porque o valor por omissão de
  // `permissions` é ["view"].
  "download",
]);

export const createShareLinkSchema = z.object({
  permissions: z
    .array(shareLinkPermissionSchema)
    .min(1, "Escolha pelo menos uma permissão.")
    .default(["view"]),
  // Exigência sobre quem já tem "upload", não uma permissão nova — por
  // isso fica fora do array `permissions` (ver migração 0010).
  requireCaption: z.boolean().default(false),
  pin: z
    .string()
    .trim()
    .regex(/^\d{4,8}$/, "O PIN deve ter entre 4 e 8 dígitos.")
    .optional(),
  expiresAt: z.iso.datetime().optional(),
});

export type CreateShareLinkInput = z.infer<typeof createShareLinkSchema>;

export const resolveAlbumSchema = z.object({
  token: z.string().trim().min(1, "Token em falta."),
  pin: z.string().trim().max(8).optional(),
});

export type ResolveAlbumInput = z.infer<typeof resolveAlbumSchema>;
