// Package httpapi contém o roteador e os handlers HTTP.
package httpapi

import (
	"context"
	"net/http"
	"net/netip"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"manuais/backend/internal/auth"
	"manuais/backend/internal/catalogo"
	"manuais/backend/internal/db"
	"manuais/backend/internal/sinc"
	"manuais/backend/internal/storage"
)

// Pinger é o que o healthcheck precisa do banco (*pgxpool.Pool satisfaz).
type Pinger interface {
	Ping(ctx context.Context) error
}

type Deps struct {
	Banco    Pinger
	Usuarios UsuarioStore
	Tokens   *auth.Emissor
	// ProxiesConfiaveis: de quem aceitar X-Forwarded-For (vazio = de ninguém).
	ProxiesConfiaveis []netip.Prefix

	// Q faz as leituras do catálogo; Catalogo, as escritas transacionais.
	Q        db.Querier
	Catalogo *catalogo.Servico

	Arquivos ArquivoStore
	Storage  storage.FileStorage
	// Sincronizar atualiza o espelho do storage no banco.
	Sincronizar func(ctx context.Context) (sinc.Resultado, error)
}

func NovoRouter(d Deps) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.Recoverer)

	r.NotFound(func(w http.ResponseWriter, _ *http.Request) {
		escreverErro(w, http.StatusNotFound, "nao_encontrado", "Rota não encontrada.")
	})
	r.MethodNotAllowed(func(w http.ResponseWriter, _ *http.Request) {
		escreverErro(w, http.StatusMethodNotAllowed, "metodo_nao_permitido", "Método não permitido.")
	})

	// Públicas.
	r.Get("/healthz", d.saude)
	r.Post("/auth/login", d.login(novoLimitador(limiteLoginMax, limiteLoginJanela)))

	// Todo o resto exige login.
	r.Group(func(r chi.Router) {
		r.Use(d.autenticar)
		r.Get("/me", d.eu)
		r.Put("/me/senha", d.trocarSenha)
		r.Get("/marcas", d.listarMarcas)
		r.Get("/modelos", d.listarModelos)
		r.Get("/motores", d.listarMotores)
		r.Get("/veiculos", d.listarVeiculos)
		r.Get("/documentos", d.listarDocumentos(false))
		r.Get("/documentos/{id}", d.detalharDocumento)
		r.Get("/documentos/{id}/arquivo", d.arquivoDoDocumento)
		r.Get("/favoritos", d.listarDocumentos(true))
		r.Post("/favoritos/{documento_id}", d.definirFavorito(true))
		r.Delete("/favoritos/{documento_id}", d.definirFavorito(false))

		r.Route("/admin", func(r chi.Router) {
			r.Use(exigirAdmin)
			r.Get("/drive/pendentes", d.pendentes)
			r.Post("/drive/sincronizar", d.sincronizar)
			r.Get("/drive/arquivos/{file_id}/preview", d.preview)
			r.Post("/drive/arquivos/{file_id}/ignorar", d.definirIgnorado(true))
			r.Delete("/drive/arquivos/{file_id}/ignorar", d.definirIgnorado(false))

			r.Get("/usuarios", d.listarUsuarios)
			r.Post("/usuarios", d.criarUsuario)
			r.Put("/usuarios/{id}", d.atualizarUsuario)

			r.Post("/marcas", d.salvarMarca)
			r.Put("/marcas/{id}", d.salvarMarca)
			r.Delete("/marcas/{id}", d.excluir(func(q *db.Queries, r *http.Request, id int64) (int64, error) {
				return q.ExcluirMarca(r.Context(), id)
			}))
			r.Post("/modelos", d.salvarModelo)
			r.Put("/modelos/{id}", d.salvarModelo)
			r.Delete("/modelos/{id}", d.excluir(func(q *db.Queries, r *http.Request, id int64) (int64, error) {
				return q.ExcluirModelo(r.Context(), id)
			}))
			r.Post("/motores", d.salvarMotor)
			r.Put("/motores/{id}", d.salvarMotor)
			r.Delete("/motores/{id}", d.excluir(func(q *db.Queries, r *http.Request, id int64) (int64, error) {
				return q.ExcluirMotor(r.Context(), id)
			}))
			r.Post("/veiculos", d.salvarVeiculo)
			r.Put("/veiculos/{id}", d.salvarVeiculo)
			r.Delete("/veiculos/{id}", d.excluir(func(q *db.Queries, r *http.Request, id int64) (int64, error) {
				return q.ExcluirVeiculo(r.Context(), id)
			}))
			r.Post("/documentos", d.criarDocumento)
			r.Put("/documentos/{id}", d.atualizarDocumento)
			r.Delete("/documentos/{id}", d.excluirDocumento)
		})
	})
	return r
}

func (d Deps) saude(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	if err := d.Banco.Ping(ctx); err != nil {
		escreverErro(w, http.StatusServiceUnavailable, "banco_indisponivel", "Banco de dados indisponível.")
		return
	}
	escreverJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
