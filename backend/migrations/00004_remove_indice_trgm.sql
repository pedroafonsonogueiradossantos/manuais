-- +goose Up
-- A busca compara palavra a palavra com word_similarity dentro de uma
-- subconsulta, forma que não usa este índice; ele só encarecia as escritas.
DROP INDEX documento_busca_trgm_idx;

-- +goose Down
CREATE INDEX documento_busca_trgm_idx ON documento USING gin (busca_texto gin_trgm_ops);
