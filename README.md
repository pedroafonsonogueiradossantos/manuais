# Manuais

App de manuais técnicos para mecânicos. Os arquivos ficam no Google Drive; o
backend guarda o catálogo no Postgres e faz proxy dos downloads.

- `backend/` — API em Go (chi, pgx, sqlc, goose)
- `app/` — app Flutter (Android; o código se mantém compatível com iOS)

## Requisitos

- Go 1.27+
- Docker com Compose (seu usuário precisa estar no grupo `docker`)
- `sqlc`, só para quem alterar as queries:
  `go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest`

## Subir o ambiente local

```bash
cp .env.example .env
make banco
make api
```

Antes do `make api`, preencha `JWT_SECRET` no `.env` (`openssl rand -base64 48`).

A API aplica as migrations ao iniciar. Confira com:

```bash
curl localhost:8080/healthz
```

Se a porta 5432 já estiver em uso, troque `POSTGRES_PORT` e as duas URLs no `.env`.

## Criar o primeiro admin

```bash
make admin NOME="Seu Nome" EMAIL=voce@exemplo.com PAPEL=admin
```

O comando pede a senha no terminal (8 a 72 caracteres). Ela não é aceita por
argumento para não ficar no histórico do shell.

## Login

```bash
curl -s localhost:8080/auth/login -d '{"email":"voce@exemplo.com","senha":"..."}'
```

A resposta traz `token` (JWT, 30 dias), `expira_em` e `usuario`. As demais rotas
exigem `Authorization: Bearer <token>`. Desativar o usuário ou trocar a senha
invalida os tokens já emitidos.

## Testes

```bash
make teste
```

Os testes de integração usam o banco `manuais_teste` (criado pelo compose) e são
pulados quando `TEST_DATABASE_URL` não está definido.

## Google Drive

1. No [Google Cloud Console](https://console.cloud.google.com/), crie um projeto.
2. Em **APIs e serviços → Biblioteca**, ative a **Google Drive API**.
3. Em **IAM e administrador → Contas de serviço**, crie uma conta de serviço
   (não precisa de papel no projeto).
4. Na conta criada, **Chaves → Adicionar chave → JSON**. Guarde o arquivo fora
   do repositório, só no servidor.
5. No Drive, compartilhe a pasta dos manuais com o e-mail da conta de serviço
   (`...@...iam.gserviceaccount.com`) como **Leitor**.
6. No `.env`, aponte `GOOGLE_APPLICATION_CREDENTIALS` para o JSON e preencha
   `DRIVE_ROOT_FOLDER_ID` com o trecho da URL da pasta depois de `/folders/`.

Não torne os arquivos públicos nem coloque a chave no app: só o backend fala com
o Drive.

## App

```bash
cd app
flutter test
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

Veja [app/README.md](app/README.md) para o endereço da API em aparelho físico.

O app tem três abas: **Buscar** (catálogo do servidor, com filtros de marca,
modelo, motor e tipo), **Favoritos** e **Baixados** (arquivos salvos no
aparelho, com busca que funciona sem internet). No menu da conta ficam as
configurações (download automático dos favoritos no Wi-Fi, troca de senha) e,
para administradores, a catalogação dos arquivos do Drive, a manutenção dos
cadastros e os usuários.

Depois de mudar as tabelas em `app/lib/offline/banco_local.dart`, regenere o
código do banco local:

```bash
cd app && dart run build_runner build
```

## Rotas

Todas exigem `Authorization: Bearer <token>`, menos `/healthz` e `/auth/login`.
Listas paginadas aceitam `?page=` e devolvem `itens`, `total`, `pagina`, `por_pagina`.

| Rota | O que faz |
|---|---|
| `POST /auth/login` | e-mail + senha → token |
| `GET /me`, `PUT /me/senha` | usuário logado; troca da própria senha (devolve token novo) |
| `GET /marcas`, `/modelos?marca_id=`, `/motores`, `/veiculos?modelo_id=&motor_id=` | cadastros para filtros |
| `GET /documentos?q=&marca_id=&modelo_id=&motor_id=&tipo=` | busca tolerante a erro de digitação |
| `GET /documentos/{id}` | metadados, veículos e motores associados |
| `GET /documentos/{id}/arquivo` | proxy do arquivo (aceita `Range`, `If-None-Match`) |
| `GET /favoritos`, `POST`/`DELETE /favoritos/{documento_id}` | favoritos do usuário |
| `GET /admin/drive/pendentes?q=&ignorados=` | arquivos do Drive ainda não catalogados |
| `POST /admin/drive/sincronizar` | relê a pasta do Drive agora (também roda a cada 30 min) |
| `GET /admin/drive/arquivos/{file_id}/preview` | proxy para ver antes de catalogar |
| `POST`/`DELETE /admin/drive/arquivos/{file_id}/ignorar` | tira/devolve um arquivo da fila |
| `POST`/`PUT`/`DELETE /admin/{marcas,modelos,motores,veiculos,documentos}` | catálogo |
| `GET`/`POST`/`PUT /admin/usuarios` | gestão de usuários |

Tipos de documento: `manual_servico`, `diagrama_eletrico`, `foto`, `outro`.

## Formato de erro da API

```json
{"erro": {"codigo": "nao_encontrado", "mensagem": "Rota não encontrada."}}
```
