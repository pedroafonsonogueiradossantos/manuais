-- +goose Up
-- Tokens emitidos antes da última troca de senha deixam de valer.
ALTER TABLE usuario ADD COLUMN senha_alterada_em timestamptz NOT NULL DEFAULT now();

-- +goose Down
ALTER TABLE usuario DROP COLUMN senha_alterada_em;
