package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"manuais/backend/internal/db"
	"manuais/backend/internal/usuarios"
)

const (
	limiteLoginMax    = 10
	limiteLoginJanela = time.Minute
)

// UsuarioStore é o que a autenticação precisa do banco (*db.Queries satisfaz).
type UsuarioStore interface {
	BuscarUsuarioPorEmail(ctx context.Context, email string) (db.Usuario, error)
	BuscarUsuarioPorID(ctx context.Context, id int64) (db.Usuario, error)
}

// hashFalso é comparado quando o e-mail não existe, para o tempo de resposta
// não revelar quais e-mails estão cadastrados.
var hashFalso, _ = bcrypt.GenerateFromPassword([]byte("senha-que-ninguem-usa"), bcrypt.DefaultCost)

type usuarioJSON struct {
	ID    int64  `json:"id"`
	Nome  string `json:"nome"`
	Email string `json:"email"`
	Papel string `json:"papel"`
}

func paraUsuarioJSON(u db.Usuario) usuarioJSON {
	return usuarioJSON{ID: u.ID, Nome: u.Nome, Email: u.Email, Papel: u.Papel}
}

func (d Deps) login(limite *limitador) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if ok, espera := limite.permitir(ipCliente(r, d.ProxiesConfiaveis)); !ok {
			w.Header().Set("Retry-After", strconv.Itoa(int(math.Ceil(espera.Seconds()))))
			escreverErro(w, http.StatusTooManyRequests, "muitas_tentativas", "Muitas tentativas de login. Aguarde um pouco.")
			return
		}

		var entrada struct {
			Email string `json:"email"`
			Senha string `json:"senha"`
		}
		r.Body = http.MaxBytesReader(w, r.Body, 4<<10)
		if err := json.NewDecoder(r.Body).Decode(&entrada); err != nil {
			escreverErro(w, http.StatusBadRequest, "requisicao_invalida", "Corpo da requisição inválido.")
			return
		}

		email := strings.ToLower(strings.TrimSpace(entrada.Email))
		u, err := d.Usuarios.BuscarUsuarioPorEmail(r.Context(), email)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			erroInterno(w, "buscar usuário no login", err)
			return
		}
		existe := err == nil

		hash := hashFalso
		if existe {
			hash = []byte(u.SenhaHash)
		}
		senhaConfere := bcrypt.CompareHashAndPassword(hash, []byte(entrada.Senha)) == nil
		if !existe || !senhaConfere || !u.Ativo {
			escreverErro(w, http.StatusUnauthorized, "credenciais_invalidas", "E-mail ou senha incorretos.")
			return
		}

		token, expira, err := d.Tokens.Emitir(u.ID)
		if err != nil {
			erroInterno(w, "emitir token", err)
			return
		}
		escreverJSON(w, http.StatusOK, map[string]any{
			"token":     token,
			"expira_em": expira.UTC(),
			"usuario":   paraUsuarioJSON(u),
		})
	}
}

type chaveContexto struct{}

// usuarioAtual só pode ser chamado em rotas atrás de autenticar.
func usuarioAtual(ctx context.Context) db.Usuario {
	return ctx.Value(chaveContexto{}).(db.Usuario)
}

// autenticar exige um Bearer token válido de um usuário ativo. O usuário é
// relido do banco a cada requisição: desativar alguém ou trocar a senha
// derruba as sessões na hora.
func (d Deps) autenticar(proximo http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok {
			naoAutenticado(w)
			return
		}
		claims, err := d.Tokens.Validar(token)
		if err != nil {
			naoAutenticado(w)
			return
		}
		u, err := d.Usuarios.BuscarUsuarioPorID(r.Context(), claims.UsuarioID)
		if errors.Is(err, pgx.ErrNoRows) {
			naoAutenticado(w)
			return
		}
		if err != nil {
			erroInterno(w, "buscar usuário do token", err)
			return
		}
		// O iat tem precisão de segundos; trunca a coluna para comparar igual.
		if !u.Ativo || claims.EmitidoEm.Before(u.SenhaAlteradaEm.Truncate(time.Second)) {
			naoAutenticado(w)
			return
		}
		proximo.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), chaveContexto{}, u)))
	})
}

// exigirAdmin deve vir depois de autenticar.
func exigirAdmin(proximo http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if usuarioAtual(r.Context()).Papel != usuarios.PapelAdmin {
			escreverErro(w, http.StatusForbidden, "sem_permissao", "Apenas administradores podem acessar.")
			return
		}
		proximo.ServeHTTP(w, r)
	})
}

func (d Deps) eu(w http.ResponseWriter, r *http.Request) {
	escreverJSON(w, http.StatusOK, paraUsuarioJSON(usuarioAtual(r.Context())))
}

func naoAutenticado(w http.ResponseWriter) {
	w.Header().Set("WWW-Authenticate", "Bearer")
	escreverErro(w, http.StatusUnauthorized, "nao_autenticado", "Faça login para continuar.")
}

func erroInterno(w http.ResponseWriter, contexto string, err error) {
	slog.Error(contexto, "erro", err)
	escreverErro(w, http.StatusInternalServerError, "erro_interno", "Erro interno. Tente novamente.")
}
