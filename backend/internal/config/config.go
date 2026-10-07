// Package config lê a configuração do processo a partir do ambiente.
package config

import (
	"errors"
	"fmt"
	"net/netip"
	"strings"
)

type Config struct {
	DatabaseURL string
	HTTPAddr    string
	JWTSecret   string
	// ProxiesConfiaveis: proxies reversos de quem a API aceita X-Forwarded-For.
	ProxiesConfiaveis []netip.Prefix
	// DrivePastaRaizID vazio = storage não configurado (a API sobe mesmo assim).
	DrivePastaRaizID string
}

// Com HS256, um segredo curto pode ser quebrado offline a partir de um token.
const jwtSecretMin = 32

// Carregar recebe a função de leitura (os.Getenv em produção) para ser testável.
func Carregar(getenv func(string) string) (Config, error) {
	url, err := URLDoBanco(getenv)
	if err != nil {
		return Config{}, err
	}
	cfg := Config{
		DatabaseURL: url,
		HTTPAddr:    getenv("HTTP_ADDR"),
		JWTSecret:   getenv("JWT_SECRET"),

		DrivePastaRaizID: getenv("DRIVE_ROOT_FOLDER_ID"),
	}
	if len(cfg.JWTSecret) < jwtSecretMin {
		return Config{}, fmt.Errorf("variável JWT_SECRET é obrigatória e precisa de pelo menos %d caracteres", jwtSecretMin)
	}
	if cfg.HTTPAddr == "" {
		cfg.HTTPAddr = ":8080"
	}
	proxies, err := lerPrefixos(getenv("TRUSTED_PROXIES"))
	if err != nil {
		return Config{}, fmt.Errorf("variável TRUSTED_PROXIES: %w", err)
	}
	cfg.ProxiesConfiaveis = proxies
	return cfg, nil
}

// URLDoBanco serve aos comandos que só precisam do banco (cmd/admin), sem
// exigir o resto da configuração da API.
func URLDoBanco(getenv func(string) string) (string, error) {
	url := getenv("DATABASE_URL")
	if url == "" {
		return "", errors.New("variável DATABASE_URL é obrigatória")
	}
	return url, nil
}

// lerPrefixos aceita IPs e CIDRs separados por vírgula.
func lerPrefixos(valor string) ([]netip.Prefix, error) {
	var prefixos []netip.Prefix
	for _, item := range strings.Split(valor, ",") {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		if p, err := netip.ParsePrefix(item); err == nil {
			prefixos = append(prefixos, p.Masked())
			continue
		}
		ip, err := netip.ParseAddr(item)
		if err != nil {
			return nil, fmt.Errorf("%q não é IP nem CIDR", item)
		}
		prefixos = append(prefixos, netip.PrefixFrom(ip, ip.BitLen()))
	}
	return prefixos, nil
}
