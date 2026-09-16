import { z } from "zod";

export const initiateUploadSchema = z.object({
  clientUploadId: z.string().trim().min(1).max(200),
  filename: z.string().trim().min(1).max(255),
  expectedSize: z.number().int().positive(),
});

export type InitiateUploadInput = z.infer<typeof initiateUploadSchema>;

/** Espelha `photos.caption` (migração 0010). */
export const CAPTION_MAX_LENGTH = 200;

/**
 * Legenda escrita por quem envia. Opcional aqui: se o link a exige é
 * decidido pela sessão, no servidor — o esquema sozinho não sabe disso.
 * Uma legenda só com espaços conta como vazia.
 */
export const captionSchema = z
  .string()
  .trim()
  .max(
    CAPTION_MAX_LENGTH,
    `A legenda não pode ter mais de ${CAPTION_MAX_LENGTH} caracteres.`,
  )
  .optional();
