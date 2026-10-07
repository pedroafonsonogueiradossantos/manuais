// Package catalogo concentra as escritas do catálogo que precisam de
// transação: documentos com suas associações e a manutenção do texto de busca.
package catalogo

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"

	"github.com/jackc/pgx/v5"

	"manuais/backend/internal/db"
)

var ErrNaoEncontrado = errors.New("registro não encontrado")

// ErroValidacao carrega uma mensagem que pode ser mostrada ao usuário.
type ErroValidacao string

func (e ErroValidacao) Error() string { return string(e) }

var Tipos = []string{"manual_servico", "diagrama_eletrico", "foto", "outro"}

// Iniciador abre transações (*pgxpool.Pool e pgx.Tx satisfazem).
type Iniciador interface {
	Begin(ctx context.Context) (pgx.Tx, error)
}

type Servico struct {
	banco Iniciador
}

func Novo(banco Iniciador) *Servico {
	return &Servico{banco: banco}
}

type Documento struct {
	Titulo        string  `json:"titulo"`
	Tipo          string  `json:"tipo"`
	StorageFileID string  `json:"storage_file_id"`
	VeiculoIDs    []int64 `json:"veiculo_ids"`
	MotorIDs      []int64 `json:"motor_ids"`
}

func (d *Documento) validar() error {
	d.Titulo = strings.TrimSpace(d.Titulo)
	if d.Titulo == "" {
		return ErroValidacao("O título é obrigatório.")
	}
	if !slices.Contains(Tipos, d.Tipo) {
		return ErroValidacao("Tipo de documento inválido.")
	}
	return nil
}

func (s *Servico) emTx(ctx context.Context, fn func(q *db.Queries) error) error {
	tx, err := s.banco.Begin(ctx)
	if err != nil {
		return fmt.Errorf("abrir transação: %w", err)
	}
	defer tx.Rollback(ctx)
	if err := fn(db.New(tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// AlterarCadastro executa uma escrita em marca, modelo, motor ou veículo e
// recalcula o texto de busca dos documentos afetados na mesma transação.
func (s *Servico) AlterarCadastro(ctx context.Context, fn func(q *db.Queries) error) error {
	return s.emTx(ctx, func(q *db.Queries) error {
		if err := fn(q); err != nil {
			return err
		}
		return q.RecalcularBuscaTextoDeTodos(ctx)
	})
}

func (s *Servico) CriarDocumento(ctx context.Context, d Documento) (int64, error) {
	if err := d.validar(); err != nil {
		return 0, err
	}
	if d.StorageFileID == "" {
		return 0, ErroValidacao("O arquivo é obrigatório.")
	}
	var id int64
	err := s.emTx(ctx, func(q *db.Queries) error {
		var err error
		id, err = q.CriarDocumento(ctx, db.CriarDocumentoParams{
			Titulo: d.Titulo, Tipo: d.Tipo, StorageFileID: d.StorageFileID,
		})
		if err != nil {
			return err
		}
		return associar(ctx, q, id, d)
	})
	return id, err
}

// AtualizarDocumento troca título, tipo e associações. O arquivo não muda.
func (s *Servico) AtualizarDocumento(ctx context.Context, id int64, d Documento) error {
	if err := d.validar(); err != nil {
		return err
	}
	return s.emTx(ctx, func(q *db.Queries) error {
		n, err := q.AtualizarDocumento(ctx, db.AtualizarDocumentoParams{ID: id, Titulo: d.Titulo, Tipo: d.Tipo})
		if err != nil {
			return err
		}
		if n == 0 {
			return ErrNaoEncontrado
		}
		if err := q.RemoverVeiculosDoDocumento(ctx, id); err != nil {
			return err
		}
		if err := q.RemoverMotoresDoDocumento(ctx, id); err != nil {
			return err
		}
		return associar(ctx, q, id, d)
	})
}

func (s *Servico) ExcluirDocumento(ctx context.Context, id int64) error {
	return s.emTx(ctx, func(q *db.Queries) error {
		n, err := q.ExcluirDocumento(ctx, id)
		if err != nil {
			return err
		}
		if n == 0 {
			return ErrNaoEncontrado
		}
		return nil
	})
}

func associar(ctx context.Context, q *db.Queries, id int64, d Documento) error {
	if ids := semRepetidos(d.VeiculoIDs); len(ids) > 0 {
		if err := q.AssociarVeiculosAoDocumento(ctx, db.AssociarVeiculosAoDocumentoParams{DocumentoID: id, VeiculoIds: ids}); err != nil {
			return err
		}
	}
	if ids := semRepetidos(d.MotorIDs); len(ids) > 0 {
		if err := q.AssociarMotoresAoDocumento(ctx, db.AssociarMotoresAoDocumentoParams{DocumentoID: id, MotorIds: ids}); err != nil {
			return err
		}
	}
	return q.RecalcularBuscaTexto(ctx, id)
}

func semRepetidos(ids []int64) []int64 {
	ids = slices.Clone(ids)
	slices.Sort(ids)
	return slices.Compact(ids)
}
