// Package fake é um FileStorage em memória para testes.
package fake

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"sort"
	"strconv"
	"strings"
	"sync"

	"manuais/backend/internal/storage"
)

type Storage struct {
	mu       sync.Mutex
	arquivos map[string]arquivo
	// ErroList, quando definido, é devolvido por List.
	ErroList error
	// Abertos registra os intervalos pedidos em Open, na ordem.
	Abertos []string
}

type arquivo struct {
	info  storage.FileInfo
	dados []byte
}

func Novo() *Storage {
	return &Storage{arquivos: map[string]arquivo{}}
}

// Por grava (ou substitui) um arquivo; o tamanho vem dos dados.
func (s *Storage) Por(info storage.FileInfo, dados []byte) {
	s.mu.Lock()
	defer s.mu.Unlock()
	info.TamanhoBytes = int64(len(dados))
	s.arquivos[info.ID] = arquivo{info: info, dados: dados}
}

func (s *Storage) Remover(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.arquivos, id)
}

func (s *Storage) List(context.Context) ([]storage.FileInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.ErroList != nil {
		return nil, s.ErroList
	}
	lista := make([]storage.FileInfo, 0, len(s.arquivos))
	for _, a := range s.arquivos {
		lista = append(lista, a.info)
	}
	sort.Slice(lista, func(i, j int) bool { return lista[i].ID < lista[j].ID })
	return lista, nil
}

func (s *Storage) Open(_ context.Context, fileID, intervalo string) (*storage.Conteudo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.Abertos = append(s.Abertos, intervalo)

	a, ok := s.arquivos[fileID]
	if !ok {
		return nil, storage.ErrNaoEncontrado
	}
	if intervalo == "" {
		return &storage.Conteudo{Corpo: io.NopCloser(bytes.NewReader(a.dados)), Tamanho: int64(len(a.dados))}, nil
	}

	inicio, fim, ok := lerIntervalo(intervalo, len(a.dados))
	if !ok {
		return nil, storage.ErrIntervaloInvalido
	}
	trecho := a.dados[inicio : fim+1]
	return &storage.Conteudo{
		Corpo:     io.NopCloser(bytes.NewReader(trecho)),
		Tamanho:   int64(len(trecho)),
		Intervalo: fmt.Sprintf("bytes %d-%d/%d", inicio, fim, len(a.dados)),
	}, nil
}

// lerIntervalo entende "bytes=N-" e "bytes=N-M", o suficiente para os testes.
func lerIntervalo(intervalo string, total int) (inicio, fim int, ok bool) {
	spec, temPrefixo := strings.CutPrefix(intervalo, "bytes=")
	de, ate, temHifen := strings.Cut(spec, "-")
	if !temPrefixo || !temHifen {
		return 0, 0, false
	}
	inicio, err := strconv.Atoi(de)
	if err != nil || inicio < 0 || inicio >= total {
		return 0, 0, false
	}
	fim = total - 1
	if ate != "" {
		fim, err = strconv.Atoi(ate)
		if err != nil || fim < inicio {
			return 0, 0, false
		}
		fim = min(fim, total-1)
	}
	return inicio, fim, true
}
