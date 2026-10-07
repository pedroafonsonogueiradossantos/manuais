package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"manuais/backend/internal/auth"
	"manuais/backend/internal/db"
)

type usuariosFake struct{ porID map[int64]db.Usuario }

func (f *usuariosFake) BuscarUsuarioPorEmail(_ context.Context, email string) (db.Usuario, error) {
	for _, u := range f.porID {
		if u.Email == email {
			return u, nil
		}
	}
	return db.Usuario{}, pgx.ErrNoRows
}

func (f *usuariosFake) BuscarUsuarioPorID(_ context.Context, id int64) (db.Usuario, error) {
	if u, ok := f.porID[id]; ok {
		return u, nil
	}
	return db.Usuario{}, pgx.ErrNoRows
}

const senhaTeste = "senha-bem-longa"

type ambiente struct {
	router   http.Handler
	usuarios *usuariosFake
	tokens   *auth.Emissor
}

func novoAmbiente(t *testing.T) *ambiente {
	t.Helper()
	hash, err := bcrypt.GenerateFromPassword([]byte(senhaTeste), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	antes := time.Now().Add(-time.Hour)
	us := &usuariosFake{porID: map[int64]db.Usuario{
		1: {ID: 1, Nome: "Ana", Email: "ana@exemplo.com", SenhaHash: string(hash), Papel: "admin", Ativo: true, SenhaAlteradaEm: antes},
		2: {ID: 2, Nome: "Beto", Email: "beto@exemplo.com", SenhaHash: string(hash), Papel: "mecanico", Ativo: true, SenhaAlteradaEm: antes},
		3: {ID: 3, Nome: "Caio", Email: "caio@exemplo.com", SenhaHash: string(hash), Papel: "mecanico", Ativo: false, SenhaAlteradaEm: antes},
	}}
	tokens := auth.NovoEmissor("segredo-de-teste-com-mais-de-32-bytes!!", time.Hour)
	return &ambiente{
		router:   NovoRouter(Deps{Banco: pingFake{}, Usuarios: us, Tokens: tokens}),
		usuarios: us,
		tokens:   tokens,
	}
}

func (a *ambiente) login(t *testing.T, email, senha string) *httptest.ResponseRecorder {
	t.Helper()
	corpo := fmt.Sprintf(`{"email":%q,"senha":%q}`, email, senha)
	req := httptest.NewRequest(http.MethodPost, "/auth/login", strings.NewReader(corpo))
	rec := httptest.NewRecorder()
	a.router.ServeHTTP(rec, req)
	return rec
}

func (a *ambiente) get(caminho, autorizacao string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, caminho, nil)
	if autorizacao != "" {
		req.Header.Set("Authorization", autorizacao)
	}
	rec := httptest.NewRecorder()
	a.router.ServeHTTP(rec, req)
	return rec
}

func (a *ambiente) tokenDe(t *testing.T, id int64) string {
	t.Helper()
	token, _, err := a.tokens.Emitir(id)
	if err != nil {
		t.Fatal(err)
	}
	return token
}

func TestLoginOK(t *testing.T) {
	a := novoAmbiente(t)
	rec := a.login(t, " Ana@Exemplo.com ", senhaTeste)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body)
	}
	if strings.Contains(rec.Body.String(), "senha") {
		t.Errorf("resposta não pode conter dados de senha: %s", rec.Body)
	}
	var corpo struct {
		Token    string    `json:"token"`
		ExpiraEm time.Time `json:"expira_em"`
		Usuario  struct {
			ID    int64  `json:"id"`
			Nome  string `json:"nome"`
			Email string `json:"email"`
			Papel string `json:"papel"`
		} `json:"usuario"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &corpo); err != nil {
		t.Fatal(err)
	}
	if corpo.Usuario.ID != 1 || corpo.Usuario.Papel != "admin" || corpo.Usuario.Email != "ana@exemplo.com" {
		t.Errorf("usuario = %+v", corpo.Usuario)
	}
	if !corpo.ExpiraEm.After(time.Now()) {
		t.Errorf("expira_em = %v", corpo.ExpiraEm)
	}

	// O token devolvido precisa abrir uma rota protegida.
	if rec := a.get("/me", "Bearer "+corpo.Token); rec.Code != http.StatusOK {
		t.Fatalf("/me com o token do login: status %d: %s", rec.Code, rec.Body)
	}
}

func TestLoginRecusa(t *testing.T) {
	casos := map[string]struct{ email, senha string }{
		"senha errada":        {"ana@exemplo.com", "outra-senha-qualquer"},
		"e-mail desconhecido": {"ninguem@exemplo.com", senhaTeste},
		"usuário inativo":     {"caio@exemplo.com", senhaTeste},
		"campos vazios":       {"", ""},
	}
	for nome, c := range casos {
		t.Run(nome, func(t *testing.T) {
			rec := novoAmbiente(t).login(t, c.email, c.senha)
			if rec.Code != http.StatusUnauthorized {
				t.Fatalf("status = %d, quero 401", rec.Code)
			}
			// Mesmo código em todos os casos: não revela se o e-mail existe.
			verificarErro(t, rec, "credenciais_invalidas")
		})
	}
}

func TestLoginCorpoInvalido(t *testing.T) {
	a := novoAmbiente(t)
	req := httptest.NewRequest(http.MethodPost, "/auth/login", strings.NewReader("{não é json"))
	rec := httptest.NewRecorder()
	a.router.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, quero 400", rec.Code)
	}
	verificarErro(t, rec, "requisicao_invalida")
}

func TestLoginLimiteDeTentativas(t *testing.T) {
	a := novoAmbiente(t)
	for i := 0; i < limiteLoginMax; i++ {
		if rec := a.login(t, "ana@exemplo.com", "errada-errada"); rec.Code != http.StatusUnauthorized {
			t.Fatalf("tentativa %d: status %d", i+1, rec.Code)
		}
	}
	rec := a.login(t, "ana@exemplo.com", senhaTeste)
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, quero 429", rec.Code)
	}
	if rec.Header().Get("Retry-After") == "" {
		t.Error("faltou Retry-After")
	}
	verificarErro(t, rec, "muitas_tentativas")
}

func TestRotaProtegida(t *testing.T) {
	a := novoAmbiente(t)

	outro := auth.NovoEmissor("outro-segredo-tambem-com-32-bytes-ou-mais", time.Hour)
	tokenForjado, _, _ := outro.Emitir(1)

	casos := map[string]string{
		"sem cabeçalho":       "",
		"sem Bearer":          a.tokenDe(t, 1),
		"token lixo":          "Bearer abc",
		"assinatura errada":   "Bearer " + tokenForjado,
		"usuário inativo":     "Bearer " + a.tokenDe(t, 3),
		"usuário inexistente": "Bearer " + a.tokenDe(t, 99),
	}
	for nome, autorizacao := range casos {
		t.Run(nome, func(t *testing.T) {
			rec := a.get("/me", autorizacao)
			if rec.Code != http.StatusUnauthorized {
				t.Fatalf("status = %d, quero 401", rec.Code)
			}
			verificarErro(t, rec, "nao_autenticado")
		})
	}
}

func TestTokenAnteriorATrocaDeSenhaNaoVale(t *testing.T) {
	a := novoAmbiente(t)
	token := a.tokenDe(t, 2)

	u := a.usuarios.porID[2]
	u.SenhaAlteradaEm = time.Now().Add(time.Minute)
	a.usuarios.porID[2] = u

	if rec := a.get("/me", "Bearer "+token); rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, quero 401", rec.Code)
	}
}

func TestTokenEmitidoNoMesmoSegundoDaSenhaVale(t *testing.T) {
	a := novoAmbiente(t)
	// O iat do JWT tem precisão de segundos; a coluna, de microssegundos.
	u := a.usuarios.porID[2]
	u.SenhaAlteradaEm = time.Now().Truncate(time.Second).Add(999 * time.Millisecond)
	a.usuarios.porID[2] = u

	if rec := a.get("/me", "Bearer "+a.tokenDe(t, 2)); rec.Code != http.StatusOK {
		t.Fatalf("status = %d, quero 200: %s", rec.Code, rec.Body)
	}
}

func TestExigirAdmin(t *testing.T) {
	a := novoAmbiente(t)
	d := Deps{Usuarios: a.usuarios, Tokens: a.tokens}
	h := d.autenticar(exigirAdmin(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})))

	chamar := func(id int64) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodGet, "/admin/qualquer", nil)
		req.Header.Set("Authorization", "Bearer "+a.tokenDe(t, id))
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec
	}

	if rec := chamar(1); rec.Code != http.StatusNoContent {
		t.Errorf("admin: status %d, quero 204", rec.Code)
	}
	rec := chamar(2)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("mecânico: status %d, quero 403", rec.Code)
	}
	verificarErro(t, rec, "sem_permissao")
}
