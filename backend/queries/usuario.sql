-- name: CriarUsuario :one
INSERT INTO usuario (nome, email, senha_hash, papel)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: BuscarUsuarioPorEmail :one
SELECT * FROM usuario WHERE email = $1;

-- name: BuscarUsuarioPorID :one
SELECT * FROM usuario WHERE id = $1;

-- name: ListarUsuarios :many
SELECT * FROM usuario ORDER BY nome, id;

-- name: AtualizarUsuario :one
-- senha_hash nulo mantém a senha atual. clock_timestamp (e não now) para a
-- data valer mesmo dentro de uma transação longa.
UPDATE usuario
SET nome  = @nome,
    email = @email,
    papel = @papel,
    ativo = @ativo,
    senha_hash = COALESCE(sqlc.narg('senha_hash'), senha_hash),
    senha_alterada_em = CASE
        WHEN sqlc.narg('senha_hash')::text IS NULL THEN senha_alterada_em
        ELSE clock_timestamp()
    END
WHERE id = @id
RETURNING *;
