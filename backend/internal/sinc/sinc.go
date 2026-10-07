// Package sinc espelha a listagem do storage na tabela arquivo_storage.
package sinc

import (
	"context"
	"fmt"
	"sync"

	"github.com/jackc/pgx/v5"

	"manuais/backend/internal/db"
	"manuais/backend/internal/storage"
)

// Iniciador abre transações (*pgxpool.Pool e pgx.Tx satisfazem).
type Iniciador interface {
	Begin(ctx context.Context) (pgx.Tx, error)
}

type Resultado struct {
	Arquivos  int   `json:"arquivos"`
	Removidos int64 `json:"removidos"`
}

type Sincronizador struct {
	banco   Iniciador
	storage storage.FileStorage
	// Uma sincronização por vez: o job periódico e o botão do admin concorrem.
	mu sync.Mutex
}

func Novo(banco Iniciador, st storage.FileStorage) *Sincronizador {
	return &Sincronizador{banco: banco, storage: st}
}

// Executar lista o storage, grava o que encontrou e marca como removido o que
// sumiu. Se a listagem falhar, nada é alterado.
func (s *Sincronizador) Executar(ctx context.Context) (Resultado, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	lista, err := s.storage.List(ctx)
	if err != nil {
		return Resultado{}, fmt.Errorf("listar storage: %w", err)
	}

	var p db.UpsertArquivosStorageParams
	// O mesmo arquivo pode aparecer em duas pastas; o upsert não aceita repetidos.
	vistos := make(map[string]bool, len(lista))
	for _, f := range lista {
		if vistos[f.ID] {
			continue
		}
		vistos[f.ID] = true
		p.Ids = append(p.Ids, f.ID)
		p.Nomes = append(p.Nomes, f.Nome)
		p.Caminhos = append(p.Caminhos, f.Caminho)
		p.MimeTypes = append(p.MimeTypes, f.MimeType)
		p.Tamanhos = append(p.Tamanhos, f.TamanhoBytes)
		p.Md5s = append(p.Md5s, f.MD5)
		p.Modificados = append(p.Modificados, f.ModificadoEm)
	}

	tx, err := s.banco.Begin(ctx)
	if err != nil {
		return Resultado{}, fmt.Errorf("abrir transação: %w", err)
	}
	defer tx.Rollback(ctx)

	q := db.New(tx)
	if err := q.UpsertArquivosStorage(ctx, p); err != nil {
		return Resultado{}, fmt.Errorf("gravar arquivos: %w", err)
	}
	// Slice nil viraria NULL no SQL e a comparação não marcaria nada.
	presentes := p.Ids
	if presentes == nil {
		presentes = []string{}
	}
	removidos, err := q.MarcarArquivosRemovidos(ctx, presentes)
	if err != nil {
		return Resultado{}, fmt.Errorf("marcar removidos: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return Resultado{}, fmt.Errorf("confirmar transação: %w", err)
	}
	return Resultado{Arquivos: len(p.Ids), Removidos: removidos}, nil
}
