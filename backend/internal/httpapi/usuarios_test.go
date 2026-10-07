package httpapi

import (
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"

	"manuais/backend/internal/auth"
	"manuais/backend/internal/db"
	"manuais/backend/internal/db/dbtest"
	"manuais/backend/internal/usuarios"
)

// ambienteUsuarios usa usuários de verdade no banco (login, troca de senha).
type ambienteUsuarios struct {
	*ambienteArquivos
	admin db.Usuario
}

func novoAmbienteUsuarios(t *testing.T) *ambienteUsuarios {
	t.Helper()
	tx := dbtest.Tx(t)
	q := db.New(tx)
	admin, err := usuarios.Criar(context.Background(), q, usuarios.Novo{
		Nome: "Ana", Email: "ana@exemplo.com", Senha: senhaTeste, Papel: "admin",
	})
	if err != nil {
		t.Fatal(err)
	}
	tokens := auth.NovoEmissor("segredo-de-teste-com-mais-de-32-bytes!!", time.Hour)
	base := &ambiente{tokens: tokens, router: NovoRouter(Deps{Banco: pingFake{}, Usuarios: q, Q: q, Tokens: tokens})}
	return &ambienteUsuarios{ambienteArquivos: &ambienteArquivos{ambiente: base, tx: tx}, admin: admin}
}

type usuarioResposta struct {
	ID    int64  `json:"id"`
	Nome  string `json:"nome"`
	Email string `json:"email"`
	Papel string `json:"papel"`
	Ativo bool   `json:"ativo"`
}

func (a *ambienteUsuarios) loginStatus(t *testing.T, email, senha string) int {
	t.Helper()
	return a.login(t, email, senha).Code
}

func TestAdminGerenciaUsuarios(t *testing.T) {
	a := novoAmbienteUsuarios(t)
	admin := a.admin.ID

	var beto usuarioResposta
	status := a.req(t, http.MethodPost, "/admin/usuarios", admin, map[string]any{
		"nome": "Beto", "email": "Beto@Exemplo.com", "senha": "senha-do-beto", "papel": "mecanico",
	}, &beto)
	if status != http.StatusCreated || beto.ID == 0 || beto.Email != "beto@exemplo.com" || !beto.Ativo || beto.Papel != "mecanico" {
		t.Fatalf("criar: status %d, %+v", status, beto)
	}
	if got := a.loginStatus(t, "beto@exemplo.com", "senha-do-beto"); got != http.StatusOK {
		t.Fatalf("login do usuário novo: status %d", got)
	}

	var lista []usuarioResposta
	a.req(t, http.MethodGet, "/admin/usuarios", admin, nil, &lista)
	if len(lista) != 2 || lista[0].Nome != "Ana" || lista[1].Nome != "Beto" {
		t.Errorf("lista = %+v", lista)
	}

	caminho := fmt.Sprintf("/admin/usuarios/%d", beto.ID)
	// Redefinir a senha e renomear.
	status = a.req(t, http.MethodPut, caminho, admin, map[string]any{
		"nome": "Roberto", "email": "beto@exemplo.com", "papel": "mecanico", "ativo": true, "senha": "senha-nova-do-beto",
	}, &beto)
	if status != http.StatusOK || beto.Nome != "Roberto" {
		t.Fatalf("editar: status %d, %+v", status, beto)
	}
	if got := a.loginStatus(t, "beto@exemplo.com", "senha-do-beto"); got != http.StatusUnauthorized {
		t.Errorf("senha antiga ainda vale: status %d", got)
	}
	if got := a.loginStatus(t, "beto@exemplo.com", "senha-nova-do-beto"); got != http.StatusOK {
		t.Errorf("senha nova não vale: status %d", got)
	}

	// Editar sem senha mantém a senha; desativar bloqueia o login.
	a.req(t, http.MethodPut, caminho, admin, map[string]any{
		"nome": "Roberto", "email": "beto@exemplo.com", "papel": "mecanico", "ativo": false,
	}, nil)
	if got := a.loginStatus(t, "beto@exemplo.com", "senha-nova-do-beto"); got != http.StatusUnauthorized {
		t.Errorf("usuário desativado conseguiu logar: status %d", got)
	}

	// Erros.
	novo := func(extra map[string]any) map[string]any {
		m := map[string]any{"nome": "X", "email": "x@exemplo.com", "senha": "senha-bem-longa", "papel": "mecanico", "ativo": true}
		for k, v := range extra {
			m[k] = v
		}
		return m
	}
	const naoProcessavel = http.StatusUnprocessableEntity
	a.exigirErro(t, http.MethodPost, "/admin/usuarios", admin, novo(map[string]any{"senha": "curta"}), naoProcessavel, "validacao")
	a.exigirErro(t, http.MethodPost, "/admin/usuarios", admin, novo(map[string]any{"papel": "dono"}), naoProcessavel, "validacao")
	a.exigirErro(t, http.MethodPut, "/admin/usuarios/999999", admin, novo(nil), http.StatusNotFound, "nao_encontrado")
	a.exigirErro(t, http.MethodGet, "/admin/usuarios", beto.ID, nil, http.StatusUnauthorized, "nao_autenticado") // desativado

	// O admin não pode se trancar para fora.
	proprio := fmt.Sprintf("/admin/usuarios/%d", admin)
	a.exigirErro(t, http.MethodPut, proprio, admin, novo(map[string]any{"nome": "Ana", "email": "ana@exemplo.com", "papel": "admin", "ativo": false}), naoProcessavel, "validacao")
	a.exigirErro(t, http.MethodPut, proprio, admin, novo(map[string]any{"nome": "Ana", "email": "ana@exemplo.com", "papel": "mecanico"}), naoProcessavel, "validacao")

	// Por último: a violação de unicidade aborta a transação do teste.
	a.exigirErro(t, http.MethodPost, "/admin/usuarios", admin, novo(map[string]any{"email": "ana@exemplo.com"}), http.StatusConflict, "conflito")
}

func TestTrocarAPropriaSenha(t *testing.T) {
	a := novoAmbienteUsuarios(t)
	id := a.admin.ID

	a.exigirErro(t, http.MethodPut, "/me/senha", id, map[string]any{"senha_atual": "errada-errada", "senha_nova": "outra-senha-longa"}, http.StatusUnprocessableEntity, "senha_atual_incorreta")
	a.exigirErro(t, http.MethodPut, "/me/senha", id, map[string]any{"senha_atual": senhaTeste, "senha_nova": "curta"}, http.StatusUnprocessableEntity, "validacao")

	var r struct {
		Token    string    `json:"token"`
		ExpiraEm time.Time `json:"expira_em"`
	}
	status := a.req(t, http.MethodPut, "/me/senha", id, map[string]any{"senha_atual": senhaTeste, "senha_nova": "outra-senha-longa"}, &r)
	if status != http.StatusOK || r.Token == "" {
		t.Fatalf("trocar senha: status %d, %+v", status, r)
	}
	// O token novo devolvido continua valendo depois da troca.
	if rec := a.get("/me", "Bearer "+r.Token); rec.Code != http.StatusOK {
		t.Errorf("/me com o token novo: status %d", rec.Code)
	}
	if got := a.loginStatus(t, "ana@exemplo.com", senhaTeste); got != http.StatusUnauthorized {
		t.Errorf("senha antiga ainda vale: status %d", got)
	}
	if got := a.loginStatus(t, "ana@exemplo.com", "outra-senha-longa"); got != http.StatusOK {
		t.Errorf("senha nova não vale: status %d", got)
	}

	depois, err := db.New(a.tx).BuscarUsuarioPorID(context.Background(), id)
	if err != nil {
		t.Fatal(err)
	}
	if !depois.SenhaAlteradaEm.After(a.admin.SenhaAlteradaEm) {
		t.Error("senha_alterada_em não avançou: tokens antigos continuariam válidos")
	}
}
