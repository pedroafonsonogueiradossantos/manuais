package httpapi

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"mime"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"manuais/backend/internal/db"
	"manuais/backend/internal/storage"
)

const porPagina = 50

// ArquivoStore é o que as rotas de arquivo precisam do banco (*db.Queries satisfaz).
type ArquivoStore interface {
	BuscarArquivoStorage(ctx context.Context, storageFileID string) (db.ArquivoStorage, error)
	BuscarArquivoDoDocumento(ctx context.Context, documentoID int64) (db.ArquivoStorage, error)
	ListarPendentes(ctx context.Context, arg db.ListarPendentesParams) ([]db.ArquivoStorage, error)
	ContarPendentes(ctx context.Context, arg db.ContarPendentesParams) (int64, error)
	DefinirArquivoIgnorado(ctx context.Context, arg db.DefinirArquivoIgnoradoParams) (int64, error)
}

type arquivoJSON struct {
	StorageFileID string     `json:"storage_file_id"`
	Nome          string     `json:"nome"`
	Caminho       string     `json:"caminho"`
	MimeType      string     `json:"mime_type"`
	TamanhoBytes  int64      `json:"tamanho_bytes"`
	ModificadoEm  *time.Time `json:"modificado_em"`
	Ignorado      bool       `json:"ignorado"`
}

// pagina lê ?page= (a partir de 1); valor ausente ou inválido vale 1.
func pagina(r *http.Request) int {
	n, err := strconv.Atoi(r.URL.Query().Get("page"))
	if err != nil || n < 1 {
		return 1
	}
	return n
}

func (d Deps) pendentes(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	pag := pagina(r)
	ignorados := q.Get("ignorados") == "true"
	busca := strings.TrimSpace(q.Get("q"))

	total, err := d.Arquivos.ContarPendentes(r.Context(), db.ContarPendentesParams{Ignorados: ignorados, Busca: busca})
	if err != nil {
		erroInterno(w, "contar pendentes", err)
		return
	}
	linhas, err := d.Arquivos.ListarPendentes(r.Context(), db.ListarPendentesParams{
		Ignorados:    ignorados,
		Busca:        busca,
		Limite:       porPagina,
		Deslocamento: int32((pag - 1) * porPagina),
	})
	if err != nil {
		erroInterno(w, "listar pendentes", err)
		return
	}

	itens := make([]arquivoJSON, 0, len(linhas))
	for _, a := range linhas {
		itens = append(itens, arquivoJSON{
			StorageFileID: a.StorageFileID,
			Nome:          a.Nome,
			Caminho:       a.Caminho,
			MimeType:      a.MimeType,
			TamanhoBytes:  a.TamanhoBytes,
			ModificadoEm:  a.ModificadoEm,
			Ignorado:      a.Ignorado,
		})
	}
	escreverJSON(w, http.StatusOK, map[string]any{
		"itens":      itens,
		"total":      total,
		"pagina":     pag,
		"por_pagina": porPagina,
	})
}

func (d Deps) sincronizar(w http.ResponseWriter, r *http.Request) {
	res, err := d.Sincronizar(r.Context())
	if err != nil {
		erroDeStorage(w, "sincronizar storage", err)
		return
	}
	escreverJSON(w, http.StatusOK, res)
}

func (d Deps) definirIgnorado(ignorado bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		n, err := d.Arquivos.DefinirArquivoIgnorado(r.Context(), db.DefinirArquivoIgnoradoParams{
			StorageFileID: chi.URLParam(r, "file_id"),
			Ignorado:      ignorado,
		})
		if err != nil {
			erroInterno(w, "definir arquivo ignorado", err)
			return
		}
		if n == 0 {
			escreverErro(w, http.StatusNotFound, "nao_encontrado", "Arquivo não encontrado.")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

// preview só serve arquivos que estão no espelho da pasta: o id vem do
// cliente e não pode virar um leitor genérico do Drive.
func (d Deps) preview(w http.ResponseWriter, r *http.Request) {
	a, err := d.Arquivos.BuscarArquivoStorage(r.Context(), chi.URLParam(r, "file_id"))
	d.responderArquivo(w, r, a, err)
}

func (d Deps) arquivoDoDocumento(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		escreverErro(w, http.StatusNotFound, "nao_encontrado", "Documento não encontrado.")
		return
	}
	a, err := d.Arquivos.BuscarArquivoDoDocumento(r.Context(), id)
	d.responderArquivo(w, r, a, err)
}

func (d Deps) responderArquivo(w http.ResponseWriter, r *http.Request, a db.ArquivoStorage, err error) {
	if errors.Is(err, pgx.ErrNoRows) {
		escreverErro(w, http.StatusNotFound, "nao_encontrado", "Arquivo não encontrado.")
		return
	}
	if err != nil {
		erroInterno(w, "buscar arquivo", err)
		return
	}
	d.servirArquivo(w, r, a)
}

// servirArquivo faz o proxy do storage em streaming: o arquivo nunca fica
// inteiro na memória. Range é repassado para permitir retomar downloads.
func (d Deps) servirArquivo(w http.ResponseWriter, r *http.Request, a db.ArquivoStorage) {
	etag := ""
	if a.Md5 != nil {
		etag = `"` + *a.Md5 + `"`
	}
	if etag != "" && r.Header.Get("If-None-Match") == etag {
		w.Header().Set("ETag", etag)
		w.WriteHeader(http.StatusNotModified)
		return
	}

	intervalo := r.Header.Get("Range")
	// If-Range: o cliente só quer o trecho se o arquivo ainda for o mesmo.
	if se := r.Header.Get("If-Range"); se != "" && se != etag {
		intervalo = ""
	}

	conteudo, err := d.Storage.Open(r.Context(), a.StorageFileID, intervalo)
	switch {
	case errors.Is(err, storage.ErrNaoEncontrado):
		escreverErro(w, http.StatusNotFound, "arquivo_indisponivel", "O arquivo não está mais disponível no armazenamento.")
		return
	case errors.Is(err, storage.ErrIntervaloInvalido):
		w.Header().Set("Content-Range", "bytes */"+strconv.FormatInt(a.TamanhoBytes, 10))
		escreverErro(w, http.StatusRequestedRangeNotSatisfiable, "intervalo_invalido", "Intervalo de bytes inválido.")
		return
	case err != nil:
		erroDeStorage(w, "abrir arquivo no storage", err)
		return
	}
	defer conteudo.Corpo.Close()

	h := w.Header()
	h.Set("Content-Type", a.MimeType)
	h.Set("Content-Disposition", mime.FormatMediaType("inline", map[string]string{"filename": a.Nome}))
	h.Set("Accept-Ranges", "bytes")
	h.Set("Cache-Control", "private, no-cache")
	if conteudo.Tamanho >= 0 {
		h.Set("Content-Length", strconv.FormatInt(conteudo.Tamanho, 10))
	}
	if etag != "" {
		h.Set("ETag", etag)
	}
	if a.ModificadoEm != nil {
		h.Set("Last-Modified", a.ModificadoEm.UTC().Format(http.TimeFormat))
	}

	status := http.StatusOK
	if conteudo.Intervalo != "" {
		h.Set("Content-Range", conteudo.Intervalo)
		status = http.StatusPartialContent
	}
	w.WriteHeader(status)

	// Depois do cabeçalho não dá mais para responder erro; cliente que
	// desconecta no meio é normal em rede móvel.
	if _, err := io.Copy(w, conteudo.Corpo); err != nil && r.Context().Err() == nil {
		slog.Warn("transmissão de arquivo interrompida", "arquivo", a.StorageFileID, "erro", err)
	}
}

func erroDeStorage(w http.ResponseWriter, contexto string, err error) {
	if errors.Is(err, storage.ErrNaoConfigurado) {
		escreverErro(w, http.StatusServiceUnavailable, "storage_nao_configurado", "O armazenamento de arquivos não está configurado no servidor.")
		return
	}
	slog.Error(contexto, "erro", err)
	escreverErro(w, http.StatusBadGateway, "storage_indisponivel", "Não foi possível acessar o armazenamento de arquivos.")
}
