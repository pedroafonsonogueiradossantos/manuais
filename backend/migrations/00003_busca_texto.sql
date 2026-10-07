-- +goose Up
-- Texto de busca de um documento: título, veículos associados, motores
-- associados e os veículos que usam esses motores. Assim "gol" encontra o
-- manual catalogado só pelo motor EA111.
-- +goose StatementBegin
CREATE FUNCTION documento_busca_texto(doc_id bigint) RETURNS text
LANGUAGE sql STABLE AS $$
    SELECT lower(unaccent(concat_ws(' ',
        (SELECT d.titulo FROM documento d WHERE d.id = doc_id),
        (SELECT string_agg(DISTINCT concat_ws(' ', ma.nome, mo.nome, mt.codigo, mt.descricao), ' ')
           FROM documento_veiculo dv
           JOIN veiculo v ON v.id = dv.veiculo_id
           JOIN modelo mo ON mo.id = v.modelo_id
           JOIN marca ma ON ma.id = mo.marca_id
           LEFT JOIN motor mt ON mt.id = v.motor_id
          WHERE dv.documento_id = doc_id),
        (SELECT string_agg(DISTINCT concat_ws(' ', mt.codigo, mt.descricao), ' ')
           FROM documento_motor dm
           JOIN motor mt ON mt.id = dm.motor_id
          WHERE dm.documento_id = doc_id),
        (SELECT string_agg(DISTINCT concat_ws(' ', ma.nome, mo.nome), ' ')
           FROM documento_motor dm
           JOIN veiculo v ON v.motor_id = dm.motor_id
           JOIN modelo mo ON mo.id = v.modelo_id
           JOIN marca ma ON ma.id = mo.marca_id
          WHERE dm.documento_id = doc_id)
    )));
$$;
-- +goose StatementEnd

-- +goose Down
DROP FUNCTION documento_busca_texto(bigint);
