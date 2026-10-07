-- +goose Up
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE TABLE marca (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome text NOT NULL UNIQUE
);

CREATE TABLE modelo (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    marca_id bigint NOT NULL REFERENCES marca (id) ON DELETE RESTRICT,
    nome     text   NOT NULL,
    UNIQUE (marca_id, nome)
);

-- Ex.: codigo "EA111", descricao "1.6 8v". O mesmo código pode ter variações.
CREATE TABLE motor (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo    text NOT NULL,
    descricao text NOT NULL DEFAULT '',
    UNIQUE (codigo, descricao)
);

-- Motor e anos são opcionais: nem sempre o admin sabe na hora de catalogar.
CREATE TABLE veiculo (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    modelo_id  bigint NOT NULL REFERENCES modelo (id) ON DELETE RESTRICT,
    motor_id   bigint REFERENCES motor (id) ON DELETE RESTRICT,
    ano_inicio smallint,
    ano_fim    smallint,
    CHECK (ano_fim IS NULL OR ano_inicio IS NULL OR ano_fim >= ano_inicio),
    UNIQUE NULLS NOT DISTINCT (modelo_id, motor_id, ano_inicio, ano_fim)
);
CREATE INDEX veiculo_motor_idx ON veiculo (motor_id);

-- Espelho da listagem do storage (hoje Google Drive), mantido pelo job de
-- sincronização. Pendentes = linhas sem documento, não ignoradas e não removidas.
CREATE TABLE arquivo_storage (
    storage_file_id text PRIMARY KEY,
    nome            text        NOT NULL,
    caminho         text        NOT NULL DEFAULT '',
    mime_type       text        NOT NULL,
    tamanho_bytes   bigint      NOT NULL DEFAULT 0,
    md5             text,
    modificado_em   timestamptz,
    ignorado        boolean     NOT NULL DEFAULT false,
    removido_em     timestamptz,
    visto_em        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE documento (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titulo          text        NOT NULL,
    tipo            text        NOT NULL
        CHECK (tipo IN ('manual_servico', 'diagrama_eletrico', 'foto', 'outro')),
    storage_file_id text        NOT NULL UNIQUE REFERENCES arquivo_storage (storage_file_id),
    -- Título + marcas + modelos + motores, sem acento e em minúsculas.
    -- Recalculado pela aplicação nas escritas do catálogo.
    busca_texto     text        NOT NULL DEFAULT '',
    criado_em       timestamptz NOT NULL DEFAULT now(),
    atualizado_em   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX documento_busca_trgm_idx ON documento USING gin (busca_texto gin_trgm_ops);

CREATE TABLE documento_veiculo (
    documento_id bigint NOT NULL REFERENCES documento (id) ON DELETE CASCADE,
    veiculo_id   bigint NOT NULL REFERENCES veiculo (id) ON DELETE CASCADE,
    PRIMARY KEY (documento_id, veiculo_id)
);
CREATE INDEX documento_veiculo_veiculo_idx ON documento_veiculo (veiculo_id);

-- Documento que vale para todo veículo com aquele motor (ex.: manual do EA111).
CREATE TABLE documento_motor (
    documento_id bigint NOT NULL REFERENCES documento (id) ON DELETE CASCADE,
    motor_id     bigint NOT NULL REFERENCES motor (id) ON DELETE CASCADE,
    PRIMARY KEY (documento_id, motor_id)
);
CREATE INDEX documento_motor_motor_idx ON documento_motor (motor_id);

CREATE TABLE usuario (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome       text        NOT NULL,
    email      text        NOT NULL UNIQUE CHECK (email = lower(email)),
    senha_hash text        NOT NULL,
    papel      text        NOT NULL CHECK (papel IN ('admin', 'mecanico')),
    ativo      boolean     NOT NULL DEFAULT true,
    criado_em  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE favorito (
    usuario_id   bigint      NOT NULL REFERENCES usuario (id) ON DELETE CASCADE,
    documento_id bigint      NOT NULL REFERENCES documento (id) ON DELETE CASCADE,
    criado_em    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (usuario_id, documento_id)
);

-- +goose Down
DROP TABLE favorito;
DROP TABLE usuario;
DROP TABLE documento_motor;
DROP TABLE documento_veiculo;
DROP TABLE documento;
DROP TABLE arquivo_storage;
DROP TABLE veiculo;
DROP TABLE motor;
DROP TABLE modelo;
DROP TABLE marca;
