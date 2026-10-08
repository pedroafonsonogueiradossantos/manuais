# Carrega o .env (se existir) e exporta para os comandos abaixo.
ifneq (,$(wildcard .env))
include .env
export
endif

.PHONY: banco api migrar admin drive teste sqlc

banco: ## sobe o Postgres local
	docker compose up -d --wait postgres

api: ## roda a API (aplica as migrations ao iniciar)
	cd backend && go run ./cmd/api

migrar: ## aplica as migrations sem subir a API
	cd backend && go run ./cmd/admin migrate

admin: ## cria usuário: make admin NOME="Fulano" EMAIL=fulano@exemplo.com PAPEL=admin
	cd backend && go run ./cmd/admin create-user --nome "$(NOME)" --email "$(EMAIL)" --papel "$(PAPEL)"

drive: ## testa o acesso à pasta do Drive configurada no .env
	cd backend && go run ./cmd/admin check-drive

teste: ## testes; os de integração rodam se TEST_DATABASE_URL estiver definido
	cd backend && go test ./...

sqlc: ## regenera internal/db a partir de queries/ e migrations/
	cd backend && sqlc generate
