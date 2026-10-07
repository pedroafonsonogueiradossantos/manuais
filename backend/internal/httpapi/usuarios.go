package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"manuais/backend/internal/usuarios"
)

// erroDeUsuario traduz os erros do pacote usuarios para a resposta HTTP.
func erroDeUsuario(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, usuarios.ErrInvalido):
		// Tira o prefixo técnico e deixa só o motivo.
		_, motivo, _ := strings.Cut(err.Error(), ": ")
		validacao(w, "Dados inválidos: "+motivo+".")
	case errors.Is(err, usuarios.ErrEmailEmUso):
		escreverErro(w, http.StatusConflict, "conflito", "Já existe um usuário com este e-mail.")
	case errors.Is(err, usuarios.ErrNaoEncontrado):
		naoEncontrado(w)
	case errors.Is(err, usuarios.ErrSenhaAtualIncorreta):
		escreverErro(w, http.StatusUnprocessableEntity, "senha_atual_incorreta", "A senha atual está incorreta.")
	default:
		erroInterno(w, "gravar usuário", err)
	}
}

func (d Deps) listarUsuarios(w http.ResponseWriter, r *http.Request) {
	lista, err := d.Q.ListarUsuarios(r.Context())
	if err != nil {
		erroInterno(w, "listar usuários", err)
		return
	}
	escreverJSON(w, http.StatusOK, lista)
}

type entradaUsuario struct {
	Nome  string `json:"nome"`
	Email string `json:"email"`
	Papel string `json:"papel"`
	Ativo bool   `json:"ativo"`
	Senha string `json:"senha"`
}

func (d Deps) criarUsuario(w http.ResponseWriter, r *http.Request) {
	var e entradaUsuario
	if !lerJSON(w, r, &e) {
		return
	}
	u, err := usuarios.Criar(r.Context(), d.Q, usuarios.Novo{Nome: e.Nome, Email: e.Email, Senha: e.Senha, Papel: e.Papel})
	if err != nil {
		erroDeUsuario(w, err)
		return
	}
	escreverJSON(w, http.StatusCreated, u)
}

func (d Deps) atualizarUsuario(w http.ResponseWriter, r *http.Request) {
	id, ok := idDaURL(w, r, "id")
	if !ok {
		return
	}
	var e entradaUsuario
	if !lerJSON(w, r, &e) {
		return
	}
	// Evita o admin se trancar para fora do sistema.
	if id == usuarioAtual(r.Context()).ID && (!e.Ativo || e.Papel != usuarios.PapelAdmin) {
		validacao(w, "Você não pode desativar nem rebaixar o seu próprio usuário.")
		return
	}
	u, err := usuarios.Atualizar(r.Context(), d.Q, id, usuarios.Alteracao{
		Nome: e.Nome, Email: e.Email, Papel: e.Papel, Ativo: e.Ativo, Senha: e.Senha,
	})
	if err != nil {
		erroDeUsuario(w, err)
		return
	}
	escreverJSON(w, http.StatusOK, u)
}

// trocarSenha devolve um token novo: a troca invalida todos os anteriores,
// inclusive o desta requisição.
func (d Deps) trocarSenha(w http.ResponseWriter, r *http.Request) {
	var e struct {
		SenhaAtual string `json:"senha_atual"`
		SenhaNova  string `json:"senha_nova"`
	}
	if !lerJSON(w, r, &e) {
		return
	}
	u, err := usuarios.TrocarSenha(r.Context(), d.Q, usuarioAtual(r.Context()), e.SenhaAtual, e.SenhaNova)
	if err != nil {
		erroDeUsuario(w, err)
		return
	}
	token, expira, err := d.Tokens.Emitir(u.ID)
	if err != nil {
		erroInterno(w, "emitir token", err)
		return
	}
	escreverJSON(w, http.StatusOK, map[string]any{"token": token, "expira_em": expira.UTC()})
}
