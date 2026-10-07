package httpapi

import (
	"net/http/httptest"
	"net/netip"
	"testing"
	"time"
)

func TestLimitador(t *testing.T) {
	agora := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	l := novoLimitador(3, time.Minute)
	l.agora = func() time.Time { return agora }

	for i := 0; i < 3; i++ {
		if ok, _ := l.permitir("a"); !ok {
			t.Fatalf("tentativa %d deveria passar", i+1)
		}
	}
	ok, espera := l.permitir("a")
	if ok {
		t.Fatal("4ª tentativa deveria ser barrada")
	}
	if espera <= 0 || espera > time.Minute {
		t.Errorf("espera = %v", espera)
	}
	if ok, _ := l.permitir("b"); !ok {
		t.Error("outra chave não deveria ser afetada")
	}

	agora = agora.Add(time.Minute + time.Second)
	if ok, _ := l.permitir("a"); !ok {
		t.Error("deveria liberar depois da janela")
	}
}

func TestIPCliente(t *testing.T) {
	confiaveis := []netip.Prefix{netip.MustParsePrefix("10.0.0.0/8")}
	casos := []struct {
		nome       string
		confiaveis []netip.Prefix
		remoto     string
		xff        string
		quero      string
	}{
		{"sem proxy ignora XFF", nil, "203.0.113.9:1234", "1.2.3.4", "203.0.113.9"},
		{"proxy confiável usa XFF", confiaveis, "10.0.0.1:1234", "198.51.100.7", "198.51.100.7"},
		{"pega o mais à direita não confiável", confiaveis, "10.0.0.1:1234", "6.6.6.6, 198.51.100.7, 10.0.0.2", "198.51.100.7"},
		{"remoto não confiável ignora XFF", confiaveis, "203.0.113.9:1234", "1.2.3.4", "203.0.113.9"},
		{"XFF inválido cai no remoto", confiaveis, "10.0.0.1:1234", "lixo", "10.0.0.1"},
	}
	for _, c := range casos {
		t.Run(c.nome, func(t *testing.T) {
			req := httptest.NewRequest("POST", "/auth/login", nil)
			req.RemoteAddr = c.remoto
			if c.xff != "" {
				req.Header.Set("X-Forwarded-For", c.xff)
			}
			if got := ipCliente(req, c.confiaveis); got != c.quero {
				t.Errorf("ip = %q, quero %q", got, c.quero)
			}
		})
	}
}
