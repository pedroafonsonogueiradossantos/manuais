package usuarios

import (
	"context"
	"errors"
	"testing"

	"golang.org/x/crypto/bcrypt"

	"manuais/backend/internal/db"
	"manuais/backend/internal/db/dbtest"
)

type repoFake struct {
	recebido db.CriarUsuarioParams
	chamado  bool
}

func (r *repoFake) CriarUsuario(_ context.Context, p db.CriarUsuarioParams) (db.Usuario, error) {
	r.chamado = true
	r.recebido = p
	return db.Usuario{ID: 1, Nome: p.Nome, Email: p.Email, SenhaHash: p.SenhaHash, Papel: p.Papel, Ativo: true}, nil
}

func (r *repoFake) AtualizarUsuario(context.Context, db.AtualizarUsuarioParams) (db.Usuario, error) {
	return db.Usuario{}, nil
}

func TestCriarNormalizaEGeraHash(t *testing.T) {
	repo := &repoFake{}
	u, err := Criar(context.Background(), repo, Novo{
		Nome: "  Zé  ", Email: "  Ze@Exemplo.COM ", Senha: "senha-bem-longa", Papel: "admin",
	})
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}
	if u.Email != "ze@exemplo.com" {
		t.Errorf("email = %q", u.Email)
	}
	if u.Nome != "Zé" {
		t.Errorf("nome = %q", u.Nome)
	}
	if repo.recebido.SenhaHash == "senha-bem-longa" {
		t.Fatal("senha gravada em texto puro")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(repo.recebido.SenhaHash), []byte("senha-bem-longa")); err != nil {
		t.Errorf("hash não confere com a senha: %v", err)
	}
}

func TestCriarValida(t *testing.T) {
	valido := Novo{Nome: "Zé", Email: "ze@exemplo.com", Senha: "senha-bem-longa", Papel: "mecanico"}
	casos := map[string]func(*Novo){
		"nome vazio":       func(n *Novo) { n.Nome = "  " },
		"email sem arroba": func(n *Novo) { n.Email = "ze.exemplo.com" },
		"senha curta":      func(n *Novo) { n.Senha = "1234567" },
		"senha longa demais para o bcrypt": func(n *Novo) {
			n.Senha = string(make([]byte, 73))
		},
		"papel desconhecido": func(n *Novo) { n.Papel = "dono" },
	}
	for nome, alterar := range casos {
		t.Run(nome, func(t *testing.T) {
			repo := &repoFake{}
			n := valido
			alterar(&n)
			_, err := Criar(context.Background(), repo, n)
			if !errors.Is(err, ErrInvalido) {
				t.Fatalf("quero ErrInvalido, veio %v", err)
			}
			if repo.chamado {
				t.Error("não deveria gravar dados inválidos")
			}
		})
	}
}

func TestCriarNoBanco(t *testing.T) {
	tx := dbtest.Tx(t)
	ctx := context.Background()
	q := db.New(tx)

	novo := Novo{Nome: "Zé", Email: "ze@exemplo.com", Senha: "senha-bem-longa", Papel: "admin"}
	u, err := Criar(ctx, q, novo)
	if err != nil {
		t.Fatalf("criar: %v", err)
	}
	if u.ID == 0 || !u.Ativo {
		t.Errorf("usuário = %+v", u)
	}

	// SAVEPOINT para a transação sobreviver à violação de unicidade.
	sp, err := tx.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	_, err = Criar(ctx, db.New(sp), novo)
	sp.Rollback(ctx)
	if !errors.Is(err, ErrEmailEmUso) {
		t.Fatalf("quero ErrEmailEmUso, veio %v", err)
	}
}
