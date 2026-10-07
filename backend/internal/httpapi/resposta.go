package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

type corpoErro struct {
	Erro detalheErro `json:"erro"`
}

type detalheErro struct {
	Codigo   string `json:"codigo"`
	Mensagem string `json:"mensagem"`
}

func escreverJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("escrever resposta", "erro", err)
	}
}

// escreverErro é o formato único de erro da API:
// {"erro":{"codigo":"...","mensagem":"..."}}
func escreverErro(w http.ResponseWriter, status int, codigo, mensagem string) {
	escreverJSON(w, status, corpoErro{Erro: detalheErro{Codigo: codigo, Mensagem: mensagem}})
}
