package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

type pingFake struct{ err error }

func (p pingFake) Ping(context.Context) error { return p.err }

func requisitar(t *testing.T, h http.Handler, metodo, caminho string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(metodo, caminho, nil))
	return rec
}

func TestSaudeOK(t *testing.T) {
	rec := requisitar(t, NovoRouter(Deps{Banco: pingFake{}}), http.MethodGet, "/healthz")

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, quero 200", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json; charset=utf-8" {
		t.Errorf("Content-Type = %q", ct)
	}
	var corpo map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &corpo); err != nil {
		t.Fatalf("corpo não é JSON: %v", err)
	}
	if corpo["status"] != "ok" {
		t.Errorf("corpo = %v", corpo)
	}
}

func TestSaudeBancoFora(t *testing.T) {
	rec := requisitar(t, NovoRouter(Deps{Banco: pingFake{err: errors.New("caiu")}}), http.MethodGet, "/healthz")

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, quero 503", rec.Code)
	}
	verificarErro(t, rec, "banco_indisponivel")
}

func TestRotaInexistenteRespondeJSON(t *testing.T) {
	rec := requisitar(t, NovoRouter(Deps{Banco: pingFake{}}), http.MethodGet, "/nao-existe")

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, quero 404", rec.Code)
	}
	verificarErro(t, rec, "nao_encontrado")
}

func TestMetodoNaoPermitidoRespondeJSON(t *testing.T) {
	rec := requisitar(t, NovoRouter(Deps{Banco: pingFake{}}), http.MethodPost, "/healthz")

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, quero 405", rec.Code)
	}
	verificarErro(t, rec, "metodo_nao_permitido")
}

func verificarErro(t *testing.T, rec *httptest.ResponseRecorder, codigo string) {
	t.Helper()
	var corpo struct {
		Erro struct {
			Codigo   string `json:"codigo"`
			Mensagem string `json:"mensagem"`
		} `json:"erro"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &corpo); err != nil {
		t.Fatalf("corpo não é JSON: %v (%s)", err, rec.Body.String())
	}
	if corpo.Erro.Codigo != codigo {
		t.Errorf("codigo = %q, quero %q", corpo.Erro.Codigo, codigo)
	}
	if corpo.Erro.Mensagem == "" {
		t.Error("mensagem vazia")
	}
}
