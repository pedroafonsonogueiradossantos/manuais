package config

import (
	"net/netip"
	"strings"
	"testing"
)

const segredo = "segredo-de-teste-com-mais-de-32-bytes!!"

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func base(extra map[string]string) func(string) string {
	m := map[string]string{"DATABASE_URL": "postgres://x", "JWT_SECRET": segredo}
	for k, v := range extra {
		m[k] = v
	}
	return env(m)
}

func TestCarregar(t *testing.T) {
	cfg, err := Carregar(base(nil))
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}
	if cfg.DatabaseURL != "postgres://x" || cfg.JWTSecret != segredo {
		t.Errorf("cfg = %+v", cfg)
	}
	if cfg.HTTPAddr != ":8080" {
		t.Errorf("HTTPAddr padrão = %q, quero :8080", cfg.HTTPAddr)
	}
	if len(cfg.ProxiesConfiaveis) != 0 {
		t.Errorf("ProxiesConfiaveis = %v, quero vazio", cfg.ProxiesConfiaveis)
	}
}

func TestCarregarHTTPAddr(t *testing.T) {
	cfg, err := Carregar(base(map[string]string{"HTTP_ADDR": ":9000"}))
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}
	if cfg.HTTPAddr != ":9000" {
		t.Errorf("HTTPAddr = %q", cfg.HTTPAddr)
	}
}

func TestCarregarProxies(t *testing.T) {
	cfg, err := Carregar(base(map[string]string{"TRUSTED_PROXIES": "10.0.0.0/8, 192.168.1.5"}))
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}
	quero := []netip.Prefix{netip.MustParsePrefix("10.0.0.0/8"), netip.MustParsePrefix("192.168.1.5/32")}
	if len(cfg.ProxiesConfiaveis) != 2 || cfg.ProxiesConfiaveis[0] != quero[0] || cfg.ProxiesConfiaveis[1] != quero[1] {
		t.Errorf("ProxiesConfiaveis = %v, quero %v", cfg.ProxiesConfiaveis, quero)
	}
}

func TestIDDaPastaDoDrive(t *testing.T) {
	const id = "1TPKF_e8tLzvRku1-jq0Uwm9R4Lq3QXoT"
	aceitos := []string{
		id,
		"  " + id + "  ",
		"/" + id + "?hl=pt-br",
		"https://drive.google.com/drive/folders/" + id,
		"https://drive.google.com/drive/u/0/folders/" + id + "?hl=pt-br",
	}
	for _, valor := range aceitos {
		got, err := IDDaPastaDoDrive(valor)
		if err != nil || got != id {
			t.Errorf("IDDaPastaDoDrive(%q) = %q, %v; quero %q", valor, got, err, id)
		}
	}
	if got, err := IDDaPastaDoDrive(""); err != nil || got != "" {
		t.Errorf("vazio deveria continuar vazio, veio %q, %v", got, err)
	}
	if _, err := IDDaPastaDoDrive("minha pasta"); err == nil || !strings.Contains(err.Error(), "DRIVE_ROOT_FOLDER_ID") {
		t.Errorf("quero erro citando DRIVE_ROOT_FOLDER_ID, veio %v", err)
	}
}

func TestCarregarRecusa(t *testing.T) {
	casos := map[string]struct {
		env   func(string) string
		citar string
	}{
		"sem DATABASE_URL":       {env(map[string]string{"JWT_SECRET": segredo}), "DATABASE_URL"},
		"sem JWT_SECRET":         {env(map[string]string{"DATABASE_URL": "postgres://x"}), "JWT_SECRET"},
		"JWT_SECRET curto":       {base(map[string]string{"JWT_SECRET": "curto"}), "JWT_SECRET"},
		"TRUSTED_PROXIES errado": {base(map[string]string{"TRUSTED_PROXIES": "abc"}), "TRUSTED_PROXIES"},
		"pasta do Drive errada":  {base(map[string]string{"DRIVE_ROOT_FOLDER_ID": "a b"}), "DRIVE_ROOT_FOLDER_ID"},
	}
	for nome, c := range casos {
		t.Run(nome, func(t *testing.T) {
			_, err := Carregar(c.env)
			if err == nil || !strings.Contains(err.Error(), c.citar) {
				t.Fatalf("quero erro citando %s, veio %v", c.citar, err)
			}
		})
	}
}
