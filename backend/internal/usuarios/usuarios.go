// Package usuarios concentra as regras de criação de usuários.
package usuarios

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"

	"manuais/backend/internal/db"
)

const (
	PapelAdmin    = "admin"
	PapelMecanico = "mecanico"

	senhaMin = 8
	// O bcrypt ignora tudo depois de 72 bytes; melhor recusar do que truncar.
	senhaMax = 72
)

var (
	ErrInvalido            = errors.New("dados de usuário inválidos")
	ErrEmailEmUso          = errors.New("e-mail já cadastrado")
	ErrNaoEncontrado       = errors.New("usuário não encontrado")
	ErrSenhaAtualIncorreta = errors.New("senha atual incorreta")
)

type Novo struct {
	Nome  string
	Email string
	Senha string
	Papel string
}

type Repositorio interface {
	CriarUsuario(ctx context.Context, arg db.CriarUsuarioParams) (db.Usuario, error)
	AtualizarUsuario(ctx context.Context, arg db.AtualizarUsuarioParams) (db.Usuario, error)
}

// normalizar valida e limpa os campos comuns a criar e atualizar.
func normalizar(nome, email, papel string) (string, string, error) {
	nome = strings.TrimSpace(nome)
	email = strings.ToLower(strings.TrimSpace(email))
	switch {
	case nome == "":
		return "", "", fmt.Errorf("%w: nome é obrigatório", ErrInvalido)
	case !emailValido(email):
		return "", "", fmt.Errorf("%w: e-mail inválido", ErrInvalido)
	case papel != PapelAdmin && papel != PapelMecanico:
		return "", "", fmt.Errorf("%w: papel deve ser %q ou %q", ErrInvalido, PapelAdmin, PapelMecanico)
	}
	return nome, email, nil
}

func gerarHash(senha string) (string, error) {
	if len(senha) < senhaMin || len(senha) > senhaMax {
		return "", fmt.Errorf("%w: a senha deve ter de %d a %d caracteres", ErrInvalido, senhaMin, senhaMax)
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(senha), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("gerar hash da senha: %w", err)
	}
	return string(hash), nil
}

// traduzir converte a violação de unicidade do e-mail em ErrEmailEmUso.
func traduzir(err error) error {
	var pgErr *pgconn.PgError
	switch {
	case err == nil:
		return nil
	case errors.As(err, &pgErr) && pgErr.Code == "23505":
		return ErrEmailEmUso
	case errors.Is(err, pgx.ErrNoRows):
		return ErrNaoEncontrado
	}
	return fmt.Errorf("gravar usuário: %w", err)
}

func Criar(ctx context.Context, repo Repositorio, n Novo) (db.Usuario, error) {
	nome, email, err := normalizar(n.Nome, n.Email, n.Papel)
	if err != nil {
		return db.Usuario{}, err
	}
	hash, err := gerarHash(n.Senha)
	if err != nil {
		return db.Usuario{}, err
	}
	u, err := repo.CriarUsuario(ctx, db.CriarUsuarioParams{Nome: nome, Email: email, SenhaHash: hash, Papel: n.Papel})
	return u, traduzir(err)
}

// Alteracao são os dados editáveis de um usuário. Senha vazia mantém a atual.
type Alteracao struct {
	Nome  string
	Email string
	Papel string
	Ativo bool
	Senha string
}

func Atualizar(ctx context.Context, repo Repositorio, id int64, a Alteracao) (db.Usuario, error) {
	nome, email, err := normalizar(a.Nome, a.Email, a.Papel)
	if err != nil {
		return db.Usuario{}, err
	}
	p := db.AtualizarUsuarioParams{ID: id, Nome: nome, Email: email, Papel: a.Papel, Ativo: a.Ativo}
	if a.Senha != "" {
		hash, err := gerarHash(a.Senha)
		if err != nil {
			return db.Usuario{}, err
		}
		p.SenhaHash = &hash
	}
	u, err := repo.AtualizarUsuario(ctx, p)
	return u, traduzir(err)
}

// TrocarSenha é a troca feita pelo próprio usuário: exige a senha atual.
func TrocarSenha(ctx context.Context, repo Repositorio, u db.Usuario, atual, nova string) (db.Usuario, error) {
	if bcrypt.CompareHashAndPassword([]byte(u.SenhaHash), []byte(atual)) != nil {
		return db.Usuario{}, ErrSenhaAtualIncorreta
	}
	return Atualizar(ctx, repo, u.ID, Alteracao{Nome: u.Nome, Email: u.Email, Papel: u.Papel, Ativo: u.Ativo, Senha: nova})
}

func emailValido(email string) bool {
	arroba := strings.IndexByte(email, '@')
	return arroba > 0 && arroba < len(email)-1 && !strings.ContainsAny(email, " \t\n")
}
