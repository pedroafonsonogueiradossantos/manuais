package auth

import (
	"errors"
	"testing"
	"time"
)

const segredo = "segredo-de-teste-com-mais-de-32-bytes!!"

func emissorEm(t time.Time) *Emissor {
	e := NovoEmissor(segredo, 30*24*time.Hour)
	e.agora = func() time.Time { return t }
	return e
}

func TestEmitirEValidar(t *testing.T) {
	agora := time.Date(2026, 1, 10, 12, 0, 0, 0, time.UTC)
	e := emissorEm(agora)

	token, expira, err := e.Emitir(42)
	if err != nil {
		t.Fatalf("emitir: %v", err)
	}
	if !expira.Equal(agora.Add(30 * 24 * time.Hour)) {
		t.Errorf("expira = %v", expira)
	}

	c, err := e.Validar(token)
	if err != nil {
		t.Fatalf("validar: %v", err)
	}
	if c.UsuarioID != 42 {
		t.Errorf("UsuarioID = %d", c.UsuarioID)
	}
	if !c.EmitidoEm.Equal(agora) {
		t.Errorf("EmitidoEm = %v", c.EmitidoEm)
	}
}

func TestValidarRecusa(t *testing.T) {
	agora := time.Date(2026, 1, 10, 12, 0, 0, 0, time.UTC)
	token, _, err := emissorEm(agora).Emitir(42)
	if err != nil {
		t.Fatal(err)
	}

	outroSegredo := NovoEmissor("outro-segredo-tambem-com-32-bytes-ou-mais", time.Hour)
	outroSegredo.agora = func() time.Time { return agora }

	casos := map[string]struct {
		emissor *Emissor
		token   string
	}{
		"expirado":         {emissorEm(agora.Add(31 * 24 * time.Hour)), token},
		"outro segredo":    {outroSegredo, token},
		"lixo":             {emissorEm(agora), "nao.e.token"},
		"vazio":            {emissorEm(agora), ""},
		"algoritmo none":   {emissorEm(agora), "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiI0MiIsImV4cCI6NDEwMjQ0NDgwMH0."},
		"sub não numérico": {emissorEm(agora), tokenComSub(t, agora, "abc")},
	}
	for nome, c := range casos {
		t.Run(nome, func(t *testing.T) {
			if _, err := c.emissor.Validar(c.token); !errors.Is(err, ErrTokenInvalido) {
				t.Fatalf("quero ErrTokenInvalido, veio %v", err)
			}
		})
	}
}

func tokenComSub(t *testing.T, agora time.Time, sub string) string {
	t.Helper()
	token, err := emissorEm(agora).assinar(sub, agora, agora.Add(time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	return token
}
