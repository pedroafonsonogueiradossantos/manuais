-- name: UpsertArquivosStorage :exec
-- Recebe a listagem inteira do storage em arrays paralelos. Arquivo que volta a
-- aparecer deixa de estar marcado como removido.
INSERT INTO arquivo_storage (storage_file_id, nome, caminho, mime_type, tamanho_bytes, md5, modificado_em)
SELECT
    unnest(@ids::text[]),
    unnest(@nomes::text[]),
    unnest(@caminhos::text[]),
    unnest(@mime_types::text[]),
    unnest(@tamanhos::bigint[]),
    NULLIF(unnest(@md5s::text[]), ''),
    unnest(@modificados::timestamptz[])
ON CONFLICT (storage_file_id) DO UPDATE SET
    nome          = EXCLUDED.nome,
    caminho       = EXCLUDED.caminho,
    mime_type     = EXCLUDED.mime_type,
    tamanho_bytes = EXCLUDED.tamanho_bytes,
    md5           = EXCLUDED.md5,
    modificado_em = EXCLUDED.modificado_em,
    removido_em   = NULL,
    visto_em      = now();

-- name: MarcarArquivosRemovidos :execrows
-- Marca como removido o que não veio na listagem atual.
UPDATE arquivo_storage
SET removido_em = now()
WHERE removido_em IS NULL
  AND storage_file_id <> ALL (@ids_presentes::text[]);

-- name: BuscarArquivoStorage :one
SELECT * FROM arquivo_storage WHERE storage_file_id = $1;

-- name: BuscarArquivoDoDocumento :one
SELECT a.*
FROM documento d
JOIN arquivo_storage a ON a.storage_file_id = d.storage_file_id
WHERE d.id = $1;

-- name: ListarPendentes :many
-- Arquivos presentes no storage e ainda sem documento. @ignorados escolhe
-- entre a fila normal (false) e a lista de ignorados (true).
SELECT a.*
FROM arquivo_storage a
WHERE a.removido_em IS NULL
  AND a.ignorado = @ignorados
  AND NOT EXISTS (SELECT 1 FROM documento d WHERE d.storage_file_id = a.storage_file_id)
  AND (@busca::text = '' OR (a.caminho || '/' || a.nome) ILIKE '%' || @busca || '%')
ORDER BY a.caminho, a.nome, a.storage_file_id
LIMIT @limite OFFSET @deslocamento;

-- name: ContarPendentes :one
SELECT count(*)
FROM arquivo_storage a
WHERE a.removido_em IS NULL
  AND a.ignorado = @ignorados
  AND NOT EXISTS (SELECT 1 FROM documento d WHERE d.storage_file_id = a.storage_file_id)
  AND (@busca::text = '' OR (a.caminho || '/' || a.nome) ILIKE '%' || @busca || '%');

-- name: DefinirArquivoIgnorado :execrows
UPDATE arquivo_storage SET ignorado = $2 WHERE storage_file_id = $1;
