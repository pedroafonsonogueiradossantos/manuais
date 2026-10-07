-- name: ListarMarcas :many
SELECT * FROM marca ORDER BY nome;

-- name: CriarMarca :one
INSERT INTO marca (nome) VALUES ($1) RETURNING *;

-- name: AtualizarMarca :one
UPDATE marca SET nome = $2 WHERE id = $1 RETURNING *;

-- name: ExcluirMarca :execrows
DELETE FROM marca WHERE id = $1;

-- name: ListarModelos :many
SELECT mo.id, mo.marca_id, ma.nome AS marca_nome, mo.nome
FROM modelo mo
JOIN marca ma ON ma.id = mo.marca_id
WHERE (sqlc.narg('marca_id')::bigint IS NULL OR mo.marca_id = sqlc.narg('marca_id'))
ORDER BY ma.nome, mo.nome;

-- name: CriarModelo :one
INSERT INTO modelo (marca_id, nome) VALUES ($1, $2) RETURNING *;

-- name: AtualizarModelo :one
UPDATE modelo SET marca_id = $2, nome = $3 WHERE id = $1 RETURNING *;

-- name: ExcluirModelo :execrows
DELETE FROM modelo WHERE id = $1;

-- name: ListarMotores :many
SELECT * FROM motor ORDER BY codigo, descricao;

-- name: CriarMotor :one
INSERT INTO motor (codigo, descricao) VALUES ($1, $2) RETURNING *;

-- name: AtualizarMotor :one
UPDATE motor SET codigo = $2, descricao = $3 WHERE id = $1 RETURNING *;

-- name: ExcluirMotor :execrows
DELETE FROM motor WHERE id = $1;

-- name: ListarVeiculos :many
-- Os três filtros são opcionais; documento_id devolve os veículos associados
-- a um documento.
SELECT v.id, v.modelo_id, mo.nome AS modelo_nome, mo.marca_id, ma.nome AS marca_nome,
       v.motor_id, mt.codigo AS motor_codigo, mt.descricao AS motor_descricao,
       v.ano_inicio, v.ano_fim
FROM veiculo v
JOIN modelo mo ON mo.id = v.modelo_id
JOIN marca ma ON ma.id = mo.marca_id
LEFT JOIN motor mt ON mt.id = v.motor_id
WHERE (sqlc.narg('modelo_id')::bigint IS NULL OR v.modelo_id = sqlc.narg('modelo_id'))
  AND (sqlc.narg('motor_id')::bigint IS NULL OR v.motor_id = sqlc.narg('motor_id'))
  AND (sqlc.narg('documento_id')::bigint IS NULL OR EXISTS (
        SELECT 1 FROM documento_veiculo dv
        WHERE dv.veiculo_id = v.id AND dv.documento_id = sqlc.narg('documento_id')))
ORDER BY ma.nome, mo.nome, mt.codigo NULLS FIRST, v.ano_inicio NULLS FIRST, v.id;

-- name: CriarVeiculo :one
-- Devolve o existente se já houver um igual: criar inline durante a
-- catalogação não deve falhar por duplicidade.
INSERT INTO veiculo (modelo_id, motor_id, ano_inicio, ano_fim)
VALUES ($1, $2, $3, $4)
ON CONFLICT (modelo_id, motor_id, ano_inicio, ano_fim)
DO UPDATE SET modelo_id = EXCLUDED.modelo_id
RETURNING id;

-- name: AtualizarVeiculo :execrows
UPDATE veiculo SET modelo_id = $2, motor_id = $3, ano_inicio = $4, ano_fim = $5 WHERE id = $1;

-- name: ExcluirVeiculo :execrows
DELETE FROM veiculo WHERE id = $1;

-- name: ListarMotoresDoDocumento :many
SELECT mt.*
FROM documento_motor dm
JOIN motor mt ON mt.id = dm.motor_id
WHERE dm.documento_id = $1
ORDER BY mt.codigo, mt.descricao;
