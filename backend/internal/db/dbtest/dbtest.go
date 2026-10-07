// Package dbtest dá aos testes de integração uma transação descartável no
// Postgres apontado por TEST_DATABASE_URL.
package dbtest

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5"

	"manuais/backend/internal/db"
)

// Chave arbitrária do advisory lock que serializa as migrations: o go test
// roda os pacotes em paralelo contra o mesmo banco.
const travaMigracao = 728_114_906

// Tx devolve uma transação que é desfeita ao fim do teste. Pula o teste se
// TEST_DATABASE_URL não estiver definido.
func Tx(t *testing.T) pgx.Tx {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL não definido")
	}
	ctx := context.Background()

	pool, err := db.Conectar(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)

	conn, err := pool.Acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := conn.Exec(ctx, "SELECT pg_advisory_lock($1)", travaMigracao); err != nil {
		t.Fatal(err)
	}
	errMigrar := db.Migrar(ctx, pool)
	_, errSoltar := conn.Exec(ctx, "SELECT pg_advisory_unlock($1)", travaMigracao)
	conn.Release()
	if errMigrar != nil {
		t.Fatal(errMigrar)
	}
	if errSoltar != nil {
		t.Fatal(errSoltar)
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { tx.Rollback(context.Background()) })
	return tx
}
