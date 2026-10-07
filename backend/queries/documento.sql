-- name: CriarDocumento :one
INSERT INTO documento (titulo, tipo, storage_file_id) VALUES ($1, $2, $3) RETURNING id;

-- name: AtualizarDocumento :execrows
UPDATE documento SET titulo = $2, tipo = $3, atualizado_em = now() WHERE id = $1;

-- name: ExcluirDocumento :execrows
DELETE FROM documento WHERE id = $1;

-- name: RemoverVeiculosDoDocumento :exec
DELETE FROM documento_veiculo WHERE documento_id = $1;

-- name: AssociarVeiculosAoDocumento :exec
INSERT INTO documento_veiculo (documento_id, veiculo_id)
SELECT @documento_id, unnest(@veiculo_ids::bigint[]);

-- name: RemoverMotoresDoDocumento :exec
DELETE FROM documento_motor WHERE documento_id = $1;

-- name: AssociarMotoresAoDocumento :exec
INSERT INTO documento_motor (documento_id, motor_id)
SELECT @documento_id, unnest(@motor_ids::bigint[]);

-- name: RecalcularBuscaTexto :exec
UPDATE documento SET busca_texto = documento_busca_texto(id) WHERE id = $1;

-- name: RecalcularBuscaTextoDeTodos :exec
-- Chamado quando marca, modelo, motor ou veículo mudam.
UPDATE documento
SET busca_texto = documento_busca_texto(id)
WHERE busca_texto IS DISTINCT FROM documento_busca_texto(id);

-- name: BuscarDocumento :one
SELECT d.id, d.titulo, d.tipo, d.storage_file_id, d.criado_em, d.atualizado_em,
       a.nome AS arquivo_nome, a.mime_type, a.tamanho_bytes,
       a.md5 AS arquivo_md5, a.modificado_em AS arquivo_modificado_em,
       (a.removido_em IS NOT NULL)::boolean AS indisponivel,
       EXISTS (SELECT 1 FROM favorito f
               WHERE f.documento_id = d.id AND f.usuario_id = @usuario_id)::boolean AS favorito
FROM documento d
JOIN arquivo_storage a ON a.storage_file_id = d.storage_file_id
WHERE d.id = @id;

-- name: ListarDocumentos :many
-- @termos são as palavras da busca: cada uma precisa aparecer no texto, seja
-- como trecho exato (cobre termos curtos como "8v"), seja por semelhança de
-- trigramas (tolera erro de digitação). Filtros por marca/modelo/motor também
-- alcançam documentos ligados só ao motor de um veículo.
WITH termos AS (
    SELECT lower(unaccent(t.termo)) AS termo
    FROM unnest(@termos::text[]) AS t (termo)
)
SELECT d.id, d.titulo, d.tipo, d.criado_em, d.atualizado_em,
       a.mime_type, a.tamanho_bytes,
       a.md5 AS arquivo_md5, a.modificado_em AS arquivo_modificado_em,
       (a.removido_em IS NOT NULL)::boolean AS indisponivel,
       EXISTS (SELECT 1 FROM favorito f
               WHERE f.documento_id = d.id AND f.usuario_id = @usuario_id)::boolean AS favorito
FROM documento d
JOIN arquivo_storage a ON a.storage_file_id = d.storage_file_id
WHERE (sqlc.narg('tipo')::text IS NULL OR d.tipo = sqlc.narg('tipo'))
  AND (NOT @so_favoritos::boolean OR EXISTS (
        SELECT 1 FROM favorito f WHERE f.documento_id = d.id AND f.usuario_id = @usuario_id))
  AND (sqlc.narg('marca_id')::bigint IS NULL
       OR EXISTS (SELECT 1 FROM documento_veiculo dv
                  JOIN veiculo v ON v.id = dv.veiculo_id
                  JOIN modelo mo ON mo.id = v.modelo_id
                  WHERE dv.documento_id = d.id AND mo.marca_id = sqlc.narg('marca_id'))
       OR EXISTS (SELECT 1 FROM documento_motor dm
                  JOIN veiculo v ON v.motor_id = dm.motor_id
                  JOIN modelo mo ON mo.id = v.modelo_id
                  WHERE dm.documento_id = d.id AND mo.marca_id = sqlc.narg('marca_id')))
  AND (sqlc.narg('modelo_id')::bigint IS NULL
       OR EXISTS (SELECT 1 FROM documento_veiculo dv
                  JOIN veiculo v ON v.id = dv.veiculo_id
                  WHERE dv.documento_id = d.id AND v.modelo_id = sqlc.narg('modelo_id'))
       OR EXISTS (SELECT 1 FROM documento_motor dm
                  JOIN veiculo v ON v.motor_id = dm.motor_id
                  WHERE dm.documento_id = d.id AND v.modelo_id = sqlc.narg('modelo_id')))
  AND (sqlc.narg('motor_id')::bigint IS NULL
       OR EXISTS (SELECT 1 FROM documento_motor dm
                  WHERE dm.documento_id = d.id AND dm.motor_id = sqlc.narg('motor_id'))
       OR EXISTS (SELECT 1 FROM documento_veiculo dv
                  JOIN veiculo v ON v.id = dv.veiculo_id
                  WHERE dv.documento_id = d.id AND v.motor_id = sqlc.narg('motor_id')))
  AND NOT EXISTS (
        SELECT 1 FROM termos t
        WHERE NOT (d.busca_texto LIKE '%' || t.termo || '%'
                   OR word_similarity(t.termo, d.busca_texto) >= @semelhanca_minima::real))
ORDER BY (SELECT coalesce(sum(word_similarity(t.termo, d.busca_texto)), 0) FROM termos t) DESC,
         d.titulo, d.id
LIMIT @limite OFFSET @deslocamento;

-- name: ContarDocumentos :one
WITH termos AS (
    SELECT lower(unaccent(t.termo)) AS termo
    FROM unnest(@termos::text[]) AS t (termo)
)
SELECT count(*)
FROM documento d
WHERE (sqlc.narg('tipo')::text IS NULL OR d.tipo = sqlc.narg('tipo'))
  AND (NOT @so_favoritos::boolean OR EXISTS (
        SELECT 1 FROM favorito f WHERE f.documento_id = d.id AND f.usuario_id = @usuario_id))
  AND (sqlc.narg('marca_id')::bigint IS NULL
       OR EXISTS (SELECT 1 FROM documento_veiculo dv
                  JOIN veiculo v ON v.id = dv.veiculo_id
                  JOIN modelo mo ON mo.id = v.modelo_id
                  WHERE dv.documento_id = d.id AND mo.marca_id = sqlc.narg('marca_id'))
       OR EXISTS (SELECT 1 FROM documento_motor dm
                  JOIN veiculo v ON v.motor_id = dm.motor_id
                  JOIN modelo mo ON mo.id = v.modelo_id
                  WHERE dm.documento_id = d.id AND mo.marca_id = sqlc.narg('marca_id')))
  AND (sqlc.narg('modelo_id')::bigint IS NULL
       OR EXISTS (SELECT 1 FROM documento_veiculo dv
                  JOIN veiculo v ON v.id = dv.veiculo_id
                  WHERE dv.documento_id = d.id AND v.modelo_id = sqlc.narg('modelo_id'))
       OR EXISTS (SELECT 1 FROM documento_motor dm
                  JOIN veiculo v ON v.motor_id = dm.motor_id
                  WHERE dm.documento_id = d.id AND v.modelo_id = sqlc.narg('modelo_id')))
  AND (sqlc.narg('motor_id')::bigint IS NULL
       OR EXISTS (SELECT 1 FROM documento_motor dm
                  WHERE dm.documento_id = d.id AND dm.motor_id = sqlc.narg('motor_id'))
       OR EXISTS (SELECT 1 FROM documento_veiculo dv
                  JOIN veiculo v ON v.id = dv.veiculo_id
                  WHERE dv.documento_id = d.id AND v.motor_id = sqlc.narg('motor_id')))
  AND NOT EXISTS (
        SELECT 1 FROM termos t
        WHERE NOT (d.busca_texto LIKE '%' || t.termo || '%'
                   OR word_similarity(t.termo, d.busca_texto) >= @semelhanca_minima::real));

-- name: AdicionarFavorito :exec
INSERT INTO favorito (usuario_id, documento_id) VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: RemoverFavorito :exec
DELETE FROM favorito WHERE usuario_id = $1 AND documento_id = $2;
