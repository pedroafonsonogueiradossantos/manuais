package drive

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"google.golang.org/api/option"

	"manuais/backend/internal/storage"
)

type arquivoFalso map[string]any

// driveFalso imita o suficiente da API REST do Drive: listagem por pasta com
// paginação e download com Range.
type driveFalso struct {
	t         *testing.T
	pastas    map[string][]arquivoFalso // id da pasta → filhos
	conteudo  map[string]string
	consultas []string
	ranges    []string
}

func (d *driveFalso) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	if strings.HasSuffix(r.URL.Path, "/files") {
		if q.Get("supportsAllDrives") != "true" || q.Get("includeItemsFromAllDrives") != "true" {
			d.t.Errorf("listagem sem as flags de drive compartilhado: %s", r.URL.RawQuery)
		}
		d.consultas = append(d.consultas, q.Get("q"))
		pastaID := strings.Split(q.Get("q"), "'")[1]
		filhos := d.pastas[pastaID]

		// Pagina de 2 em 2 para exercitar o nextPageToken.
		inicio := 0
		if q.Get("pageToken") == "p2" {
			inicio = 2
		}
		resp := map[string]any{}
		fim := len(filhos)
		if inicio == 0 && len(filhos) > 2 {
			fim = 2
			resp["nextPageToken"] = "p2"
		}
		resp["files"] = filhos[inicio:fim]
		json.NewEncoder(w).Encode(resp)
		return
	}

	id := r.URL.Path[strings.LastIndex(r.URL.Path, "/")+1:]
	if q.Get("alt") != "media" {
		d.t.Errorf("download sem alt=media: %s", r.URL)
	}
	d.ranges = append(d.ranges, r.Header.Get("Range"))
	dados, ok := d.conteudo[id]
	switch {
	case !ok:
		w.WriteHeader(http.StatusNotFound)
		io.WriteString(w, `{"error":{"code":404,"message":"File not found"}}`)
	case r.Header.Get("Range") == "bytes=999-":
		w.WriteHeader(http.StatusRequestedRangeNotSatisfiable)
		io.WriteString(w, `{"error":{"code":416,"message":"Range"}}`)
	case r.Header.Get("Range") == "bytes=2-":
		w.Header().Set("Content-Range", "bytes 2-5/6")
		w.WriteHeader(http.StatusPartialContent)
		io.WriteString(w, dados[2:])
	default:
		io.WriteString(w, dados)
	}
}

func novoStorage(t *testing.T, d *driveFalso) *Storage {
	t.Helper()
	d.t = t
	srv := httptest.NewServer(d)
	t.Cleanup(srv.Close)
	s, err := Novo(context.Background(), "raiz", option.WithEndpoint(srv.URL), option.WithHTTPClient(srv.Client()))
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestListRecursivoComPaginacaoEFiltro(t *testing.T) {
	d := &driveFalso{pastas: map[string][]arquivoFalso{
		"raiz": {
			{"id": "p-vw", "name": "VW", "mimeType": mimePasta},
			{"id": "f1", "name": "geral.pdf", "mimeType": "application/pdf", "size": "10", "md5Checksum": "aaa", "modifiedTime": "2026-01-02T03:04:05.000Z"},
			{"id": "f2", "name": "planilha", "mimeType": "application/vnd.google-apps.spreadsheet"},
			{"id": "f3", "name": "motor.jpg", "mimeType": "image/jpeg", "size": "20", "md5Checksum": "bbb", "modifiedTime": "2026-01-02T03:04:05.000Z"},
		},
		"p-vw": {
			{"id": "p-gol", "name": "Gol", "mimeType": mimePasta},
			// Pasta que aponta de volta para a raiz não pode causar laço.
			{"id": "raiz", "name": "atalho", "mimeType": mimePasta},
		},
		"p-gol": {
			{"id": "f4", "name": "gol.pdf", "mimeType": "application/pdf", "size": "30", "md5Checksum": "ccc", "modifiedTime": "2026-05-06T07:08:09.000Z"},
		},
	}}

	lista, err := novoStorage(t, d).List(context.Background())
	if err != nil {
		t.Fatalf("List: %v", err)
	}

	achados := map[string]storage.FileInfo{}
	for _, f := range lista {
		achados[f.ID] = f
	}
	if len(lista) != 3 || len(achados) != 3 {
		t.Fatalf("quero f1, f3 e f4; veio %+v", lista)
	}
	if _, ok := achados["f2"]; ok {
		t.Error("planilha do Google não deveria ser listada")
	}
	f4 := achados["f4"]
	if f4.Caminho != "VW/Gol" || f4.Nome != "gol.pdf" || f4.TamanhoBytes != 30 || f4.MD5 != "ccc" {
		t.Errorf("f4 = %+v", f4)
	}
	if !f4.ModificadoEm.Equal(time.Date(2026, 5, 6, 7, 8, 9, 0, time.UTC)) {
		t.Errorf("f4.ModificadoEm = %v", f4.ModificadoEm)
	}
	if achados["f1"].Caminho != "" {
		t.Errorf("arquivo da raiz deveria ter caminho vazio, veio %q", achados["f1"].Caminho)
	}
	// raiz (2 páginas) + VW + Gol.
	if len(d.consultas) != 4 {
		t.Errorf("consultas = %v", d.consultas)
	}
	if !strings.Contains(d.consultas[0], "trashed = false") {
		t.Errorf("consulta não exclui a lixeira: %q", d.consultas[0])
	}
}

func TestOpen(t *testing.T) {
	d := &driveFalso{conteudo: map[string]string{"f1": "abcdef"}}
	s := novoStorage(t, d)
	ctx := context.Background()

	c, err := s.Open(ctx, "f1", "")
	if err != nil {
		t.Fatalf("Open inteiro: %v", err)
	}
	corpo, _ := io.ReadAll(c.Corpo)
	c.Corpo.Close()
	if string(corpo) != "abcdef" || c.Tamanho != 6 || c.Intervalo != "" {
		t.Errorf("inteiro: corpo=%q tamanho=%d intervalo=%q", corpo, c.Tamanho, c.Intervalo)
	}

	c, err = s.Open(ctx, "f1", "bytes=2-")
	if err != nil {
		t.Fatalf("Open parcial: %v", err)
	}
	corpo, _ = io.ReadAll(c.Corpo)
	c.Corpo.Close()
	if string(corpo) != "cdef" || c.Tamanho != 4 || c.Intervalo != "bytes 2-5/6" {
		t.Errorf("parcial: corpo=%q tamanho=%d intervalo=%q", corpo, c.Tamanho, c.Intervalo)
	}
	if got := d.ranges; len(got) != 2 || got[0] != "" || got[1] != "bytes=2-" {
		t.Errorf("Range repassado ao Drive = %q", got)
	}

	if _, err := s.Open(ctx, "nao-existe", ""); !errors.Is(err, storage.ErrNaoEncontrado) {
		t.Errorf("quero ErrNaoEncontrado, veio %v", err)
	}
	if _, err := s.Open(ctx, "f1", "bytes=999-"); !errors.Is(err, storage.ErrIntervaloInvalido) {
		t.Errorf("quero ErrIntervaloInvalido, veio %v", err)
	}
}
