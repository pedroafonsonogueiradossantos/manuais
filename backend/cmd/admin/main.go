// Comando admin: tarefas administrativas fora da API.
//
//	go run ./cmd/admin migrate
//	go run ./cmd/admin create-user --nome "Fulano" --email fulano@exemplo.com --papel admin
package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"path"
	"strings"

	"golang.org/x/term"

	"manuais/backend/internal/config"
	"manuais/backend/internal/db"
	"manuais/backend/internal/storage/drive"
	"manuais/backend/internal/usuarios"
)

const uso = `uso: admin <comando> [opções]

comandos:
  migrate       aplica as migrations pendentes
  create-user   cria um usuário (--nome, --email, --papel admin|mecanico)
  check-drive   testa o acesso à pasta do Drive e mostra o que encontrou
`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, uso)
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "migrate":
		err = migrar(context.Background())
	case "create-user":
		err = criarUsuario(context.Background(), os.Args[2:])
	case "check-drive":
		err = conferirDrive(context.Background())
	default:
		fmt.Fprint(os.Stderr, uso)
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "erro:", err)
		os.Exit(1)
	}
}

func migrar(ctx context.Context) error {
	url, err := config.URLDoBanco(os.Getenv)
	if err != nil {
		return err
	}
	pool, err := db.Conectar(ctx, url)
	if err != nil {
		return err
	}
	defer pool.Close()

	if err := db.Migrar(ctx, pool); err != nil {
		return err
	}
	fmt.Println("migrations aplicadas")
	return nil
}

func criarUsuario(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("create-user", flag.ContinueOnError)
	nome := fs.String("nome", "", "nome do usuário")
	email := fs.String("email", "", "e-mail de login")
	papel := fs.String("papel", usuarios.PapelMecanico, "admin ou mecanico")
	if err := fs.Parse(args); err != nil {
		return err
	}

	url, err := config.URLDoBanco(os.Getenv)
	if err != nil {
		return err
	}

	// A senha nunca vem por argumento: ficaria no histórico do shell.
	senha, err := lerSenha()
	if err != nil {
		return err
	}

	pool, err := db.Conectar(ctx, url)
	if err != nil {
		return err
	}
	defer pool.Close()

	u, err := usuarios.Criar(ctx, db.New(pool), usuarios.Novo{
		Nome: *nome, Email: *email, Senha: senha, Papel: *papel,
	})
	if err != nil {
		return err
	}
	fmt.Printf("usuário criado: id=%d email=%s papel=%s\n", u.ID, u.Email, u.Papel)
	return nil
}

// conferirDrive lista a pasta com as mesmas credenciais da API, para
// diagnosticar a configuração sem precisar subir o servidor.
func conferirDrive(ctx context.Context) error {
	id, err := config.IDDaPastaDoDrive(os.Getenv("DRIVE_ROOT_FOLDER_ID"))
	if err != nil {
		return err
	}
	if id == "" {
		return errors.New("variável DRIVE_ROOT_FOLDER_ID é obrigatória")
	}
	if os.Getenv("GOOGLE_APPLICATION_CREDENTIALS") == "" {
		return errors.New("variável GOOGLE_APPLICATION_CREDENTIALS é obrigatória")
	}
	st, err := drive.Novo(ctx, id)
	if err != nil {
		return err
	}
	arquivos, err := st.List(ctx)
	if err != nil {
		return fmt.Errorf("%w\n(404 costuma ser ID errado ou pasta não compartilhada com a service account)", err)
	}
	fmt.Printf("pasta %s: %d arquivos catalogáveis (PDFs e imagens)\n", id, len(arquivos))
	for i, a := range arquivos {
		if i == 10 {
			fmt.Printf("  ... e mais %d\n", len(arquivos)-10)
			break
		}
		fmt.Printf("  %s\n", path.Join(a.Caminho, a.Nome))
	}
	return nil
}

// lerSenha pede a senha sem eco no terminal; fora de um terminal (pipe), lê
// uma linha da entrada padrão.
func lerSenha() (string, error) {
	fd := int(os.Stdin.Fd())
	if !term.IsTerminal(fd) {
		linha, err := bufio.NewReader(os.Stdin).ReadString('\n')
		if err != nil && linha == "" {
			return "", fmt.Errorf("ler senha da entrada padrão: %w", err)
		}
		return strings.TrimRight(linha, "\r\n"), nil
	}

	fmt.Fprint(os.Stderr, "Senha: ")
	primeira, err := term.ReadPassword(fd)
	fmt.Fprintln(os.Stderr)
	if err != nil {
		return "", err
	}
	fmt.Fprint(os.Stderr, "Confirme a senha: ")
	segunda, err := term.ReadPassword(fd)
	fmt.Fprintln(os.Stderr)
	if err != nil {
		return "", err
	}
	if string(primeira) != string(segunda) {
		return "", errors.New("as senhas não conferem")
	}
	return string(primeira), nil
}
