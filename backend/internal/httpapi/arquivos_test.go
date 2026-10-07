package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"

	"manuais/backend/internal/catalogo"
	"manuais/backend/internal/db"
	"manuais/backend/internal/db/dbtest"
	"manuais/backend/internal/sinc"
	"manuais/backend/internal/storage"
	"manuais/backend/internal/storage/fake"
)

const (
	idAdmin    = 1
	idMecanico = 2
)

type ambienteArquivos struct {
	*ambiente
	tx      pgx.Tx
	storage *fake.Storage
}

// novoAmbienteArquivos usa o Postgres de teste (as queries de pendentes são o
// que interessa testar) e o storage falso com três arquivos já sincronizados.
func novoAmbienteArquivos(t *testing.T) *ambienteArquivos {
	t.Helper()
	tx := dbtest.Tx(t)
	a := novoAmbiente(t)
	st := fake.Novo()

	// Os usuários do fake de autenticação precisam existir no banco por causa
	// das chaves estrangeiras (favoritos).
	for id, u := range a.usuarios.porID {
		_, err := tx.Exec(context.Background(),
			`INSERT INTO usuario (id, nome, email, senha_hash, papel) OVERRIDING SYSTEM VALUE VALUES ($1, $2, $3, 'x', $4)`,
			id, u.Nome, u.Email, u.Papel)
		if err != nil {
			t.Fatal(err)
		}
	}

	mod := time.Date(2026, 3, 4, 5, 6, 7, 0, time.UTC)
	st.Por(storage.FileInfo{ID: "gol", Nome: "Gol 1.6.pdf", Caminho: "VW/Gol", MimeType: "application/pdf", MD5: "md5gol", ModificadoEm: mod}, []byte("0123456789"))
	st.Por(storage.FileInfo{ID: "uno", Nome: "uno.pdf", Caminho: "Fiat", MimeType: "application/pdf", MD5: "md5uno", ModificadoEm: mod}, []byte("uno"))
	st.Por(storage.FileInfo{ID: "foto", Nome: "motor.jpg", Caminho: "VW/Gol", MimeType: "image/jpeg", ModificadoEm: mod}, []byte("jpg"))

	sincronizador := sinc.Novo(tx, st)
	a.router = NovoRouter(Deps{
		Banco:       pingFake{},
		Usuarios:    a.usuarios,
		Tokens:      a.tokens,
		Arquivos:    db.New(tx),
		Q:           db.New(tx),
		Catalogo:    catalogo.Novo(tx),
		Storage:     st,
		Sincronizar: sincronizador.Executar,
	})
	amb := &ambienteArquivos{ambiente: a, tx: tx, storage: st}
	if rec := amb.chamar(t, http.MethodPost, "/admin/drive/sincronizar", idAdmin, nil); rec.Code != http.StatusOK {
		t.Fatalf("sincronizar: status %d: %s", rec.Code, rec.Body)
	}
	return amb
}

func (a *ambienteArquivos) chamar(t *testing.T, metodo, caminho string, usuarioID int64, cabecalhos map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(metodo, caminho, nil)
	req.Header.Set("Authorization", "Bearer "+a.tokenDe(t, usuarioID))
	for k, v := range cabecalhos {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	a.router.ServeHTTP(rec, req)
	return rec
}

// catalogar cria um documento para o arquivo e devolve o id.
func (a *ambienteArquivos) catalogar(t *testing.T, storageFileID string) int64 {
	t.Helper()
	var id int64
	err := a.tx.QueryRow(context.Background(),
		`INSERT INTO documento (titulo, tipo, storage_file_id) VALUES ('Manual', 'manual_servico', $1) RETURNING id`,
		storageFileID).Scan(&id)
	if err != nil {
		t.Fatal(err)
	}
	return id
}

type respostaPendentes struct {
	Itens []struct {
		StorageFileID string     `json:"storage_file_id"`
		Nome          string     `json:"nome"`
		Caminho       string     `json:"caminho"`
		MimeType      string     `json:"mime_type"`
		TamanhoBytes  int64      `json:"tamanho_bytes"`
		ModificadoEm  *time.Time `json:"modificado_em"`
	} `json:"itens"`
	Total     int64 `json:"total"`
	Pagina    int   `json:"pagina"`
	PorPagina int   `json:"por_pagina"`
}

func (a *ambienteArquivos) pendentes(t *testing.T, query string) respostaPendentes {
	t.Helper()
	rec := a.chamar(t, http.MethodGet, "/admin/drive/pendentes"+query, idAdmin, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("pendentes%s: status %d: %s", query, rec.Code, rec.Body)
	}
	var r respostaPendentes
	if err := json.Unmarshal(rec.Body.Bytes(), &r); err != nil {
		t.Fatal(err)
	}
	return r
}

func ids(r respostaPendentes) []string {
	var out []string
	for _, i := range r.Itens {
		out = append(out, i.StorageFileID)
	}
	return out
}

func igual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestPendentes(t *testing.T) {
	a := novoAmbienteArquivos(t)

	r := a.pendentes(t, "")
	// Ordenado por caminho e nome.
	if !igual(ids(r), []string{"uno", "gol", "foto"}) || r.Total != 3 || r.Pagina != 1 || r.PorPagina != porPagina {
		t.Fatalf("pendentes iniciais = %v total=%d pagina=%d", ids(r), r.Total, r.Pagina)
	}
	gol := r.Itens[1]
	if gol.Nome != "Gol 1.6.pdf" || gol.Caminho != "VW/Gol" || gol.MimeType != "application/pdf" || gol.TamanhoBytes != 10 || gol.ModificadoEm == nil {
		t.Errorf("item gol = %+v", gol)
	}

	// Catalogado sai da fila.
	a.catalogar(t, "gol")
	if r := a.pendentes(t, ""); !igual(ids(r), []string{"uno", "foto"}) || r.Total != 2 {
		t.Errorf("depois de catalogar = %v", ids(r))
	}

	// Ignorado sai da fila e aparece na lista de ignorados.
	if rec := a.chamar(t, http.MethodPost, "/admin/drive/arquivos/foto/ignorar", idAdmin, nil); rec.Code != http.StatusNoContent {
		t.Fatalf("ignorar: status %d: %s", rec.Code, rec.Body)
	}
	if r := a.pendentes(t, ""); !igual(ids(r), []string{"uno"}) {
		t.Errorf("depois de ignorar = %v", ids(r))
	}
	if r := a.pendentes(t, "?ignorados=true"); !igual(ids(r), []string{"foto"}) {
		t.Errorf("ignorados = %v", ids(r))
	}
	if rec := a.chamar(t, http.MethodDelete, "/admin/drive/arquivos/foto/ignorar", idAdmin, nil); rec.Code != http.StatusNoContent {
		t.Fatalf("desfazer ignorar: status %d", rec.Code)
	}
	if r := a.pendentes(t, ""); !igual(ids(r), []string{"uno", "foto"}) {
		t.Errorf("depois de desfazer = %v", ids(r))
	}

	// Busca por nome ou pasta, sem diferenciar maiúsculas.
	if r := a.pendentes(t, "?q=fiat"); !igual(ids(r), []string{"uno"}) || r.Total != 1 {
		t.Errorf("busca fiat = %v", ids(r))
	}

	// Sumiu do storage: sai da fila na próxima sincronização.
	a.storage.Remover("uno")
	if rec := a.chamar(t, http.MethodPost, "/admin/drive/sincronizar", idAdmin, nil); rec.Code != http.StatusOK {
		t.Fatalf("sincronizar: %d", rec.Code)
	}
	if r := a.pendentes(t, ""); !igual(ids(r), []string{"foto"}) {
		t.Errorf("depois de remover do storage = %v", ids(r))
	}

	// Página além do fim: lista vazia, total preservado.
	if r := a.pendentes(t, "?page=2"); len(r.Itens) != 0 || r.Total != 1 || r.Pagina != 2 {
		t.Errorf("página 2 = %+v", r)
	}
}

func TestIgnorarArquivoInexistente(t *testing.T) {
	a := novoAmbienteArquivos(t)
	rec := a.chamar(t, http.MethodPost, "/admin/drive/arquivos/nao-existe/ignorar", idAdmin, nil)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, quero 404", rec.Code)
	}
	verificarErro(t, rec, "nao_encontrado")
}

func TestRotasDeAdminRecusamMecanico(t *testing.T) {
	a := novoAmbienteArquivos(t)
	rotas := []struct{ metodo, caminho string }{
		{http.MethodGet, "/admin/drive/pendentes"},
		{http.MethodPost, "/admin/drive/sincronizar"},
		{http.MethodGet, "/admin/drive/arquivos/gol/preview"},
		{http.MethodPost, "/admin/drive/arquivos/gol/ignorar"},
	}
	for _, r := range rotas {
		if rec := a.chamar(t, r.metodo, r.caminho, idMecanico, nil); rec.Code != http.StatusForbidden {
			t.Errorf("%s %s: status %d, quero 403", r.metodo, r.caminho, rec.Code)
		}
	}
}

func TestPreview(t *testing.T) {
	a := novoAmbienteArquivos(t)
	const url = "/admin/drive/arquivos/gol/preview"

	t.Run("arquivo inteiro", func(t *testing.T) {
		rec := a.chamar(t, http.MethodGet, url, idAdmin, nil)
		if rec.Code != http.StatusOK || rec.Body.String() != "0123456789" {
			t.Fatalf("status %d corpo %q", rec.Code, rec.Body)
		}
		quero := map[string]string{
			"Content-Type":   "application/pdf",
			"Content-Length": "10",
			"ETag":           `"md5gol"`,
			"Last-Modified":  "Wed, 04 Mar 2026 05:06:07 GMT",
			"Accept-Ranges":  "bytes",
		}
		for k, v := range quero {
			if got := rec.Header().Get(k); got != v {
				t.Errorf("%s = %q, quero %q", k, got, v)
			}
		}
		if cd := rec.Header().Get("Content-Disposition"); cd != `inline; filename="Gol 1.6.pdf"` {
			t.Errorf("Content-Disposition = %q", cd)
		}
	})

	t.Run("Range vira 206", func(t *testing.T) {
		rec := a.chamar(t, http.MethodGet, url, idAdmin, map[string]string{"Range": "bytes=4-"})
		if rec.Code != http.StatusPartialContent || rec.Body.String() != "456789" {
			t.Fatalf("status %d corpo %q", rec.Code, rec.Body)
		}
		if cr := rec.Header().Get("Content-Range"); cr != "bytes 4-9/10" {
			t.Errorf("Content-Range = %q", cr)
		}
		if cl := rec.Header().Get("Content-Length"); cl != "6" {
			t.Errorf("Content-Length = %q", cl)
		}
	})

	t.Run("Range inválido vira 416", func(t *testing.T) {
		rec := a.chamar(t, http.MethodGet, url, idAdmin, map[string]string{"Range": "bytes=50-"})
		if rec.Code != http.StatusRequestedRangeNotSatisfiable {
			t.Fatalf("status %d, quero 416", rec.Code)
		}
		verificarErro(t, rec, "intervalo_invalido")
	})

	t.Run("If-None-Match igual vira 304 sem tocar no storage", func(t *testing.T) {
		antes := len(a.storage.Abertos)
		rec := a.chamar(t, http.MethodGet, url, idAdmin, map[string]string{"If-None-Match": `"md5gol"`})
		if rec.Code != http.StatusNotModified || rec.Body.Len() != 0 {
			t.Fatalf("status %d corpo %q", rec.Code, rec.Body)
		}
		if len(a.storage.Abertos) != antes {
			t.Error("304 não deveria abrir o arquivo no storage")
		}
	})

	t.Run("If-Range desatualizado devolve o arquivo inteiro", func(t *testing.T) {
		rec := a.chamar(t, http.MethodGet, url, idAdmin, map[string]string{"Range": "bytes=4-", "If-Range": `"md5velho"`})
		if rec.Code != http.StatusOK || rec.Body.String() != "0123456789" {
			t.Fatalf("status %d corpo %q", rec.Code, rec.Body)
		}
	})

	t.Run("id fora do espelho vira 404", func(t *testing.T) {
		rec := a.chamar(t, http.MethodGet, "/admin/drive/arquivos/qualquer-id/preview", idAdmin, nil)
		if rec.Code != http.StatusNotFound {
			t.Fatalf("status %d, quero 404", rec.Code)
		}
		verificarErro(t, rec, "nao_encontrado")
	})

	t.Run("sumiu do storage vira 404 arquivo_indisponivel", func(t *testing.T) {
		a.storage.Remover("uno")
		rec := a.chamar(t, http.MethodGet, "/admin/drive/arquivos/uno/preview", idAdmin, nil)
		if rec.Code != http.StatusNotFound {
			t.Fatalf("status %d, quero 404", rec.Code)
		}
		verificarErro(t, rec, "arquivo_indisponivel")
	})
}

func TestArquivoDoDocumento(t *testing.T) {
	a := novoAmbienteArquivos(t)
	id := a.catalogar(t, "gol")
	url := "/documentos/" + jsonNumero(id) + "/arquivo"

	// Mecânico comum baixa documento catalogado.
	rec := a.chamar(t, http.MethodGet, url, idMecanico, nil)
	if rec.Code != http.StatusOK || rec.Body.String() != "0123456789" {
		t.Fatalf("status %d corpo %q", rec.Code, rec.Body)
	}
	if et := rec.Header().Get("ETag"); et != `"md5gol"` {
		t.Errorf("ETag = %q", et)
	}

	rec = a.chamar(t, http.MethodGet, url, idMecanico, map[string]string{"Range": "bytes=0-2"})
	if rec.Code != http.StatusPartialContent || rec.Body.String() != "012" {
		t.Errorf("Range: status %d corpo %q", rec.Code, rec.Body)
	}

	for _, caminho := range []string{"/documentos/999999/arquivo", "/documentos/abc/arquivo"} {
		rec := a.chamar(t, http.MethodGet, caminho, idMecanico, nil)
		if rec.Code != http.StatusNotFound {
			t.Errorf("%s: status %d, quero 404", caminho, rec.Code)
		}
	}

	// Sem login não baixa nada.
	req := httptest.NewRequest(http.MethodGet, url, nil)
	semLogin := httptest.NewRecorder()
	a.router.ServeHTTP(semLogin, req)
	if semLogin.Code != http.StatusUnauthorized {
		t.Errorf("sem login: status %d, quero 401", semLogin.Code)
	}
}

func TestStorageForaDoAr(t *testing.T) {
	a := novoAmbienteArquivos(t)

	a.storage.ErroList = storage.ErrNaoConfigurado
	rec := a.chamar(t, http.MethodPost, "/admin/drive/sincronizar", idAdmin, nil)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("não configurado: status %d, quero 503", rec.Code)
	}
	verificarErro(t, rec, "storage_nao_configurado")

	a.storage.ErroList = errors.New("drive fora do ar")
	rec = a.chamar(t, http.MethodPost, "/admin/drive/sincronizar", idAdmin, nil)
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("erro do storage: status %d, quero 502", rec.Code)
	}
	verificarErro(t, rec, "storage_indisponivel")
}

func jsonNumero(n int64) string {
	b, _ := json.Marshal(n)
	return string(b)
}
