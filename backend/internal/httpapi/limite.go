package httpapi

import (
	"net"
	"net/http"
	"net/netip"
	"strings"
	"sync"
	"time"
)

// limitador é um contador por chave em janela fixa, em memória. Serve para
// frear força bruta no login; não é compartilhado entre instâncias.
type limitador struct {
	mu      sync.Mutex
	max     int
	janela  time.Duration
	agora   func() time.Time
	janelas map[string]*janelaLimite
}

type janelaLimite struct {
	inicio time.Time
	n      int
}

func novoLimitador(max int, janela time.Duration) *limitador {
	return &limitador{max: max, janela: janela, agora: time.Now, janelas: map[string]*janelaLimite{}}
}

// permitir conta uma tentativa; se estourou, devolve quanto falta para liberar.
func (l *limitador) permitir(chave string) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()

	agora := l.agora()
	if len(l.janelas) > 10_000 {
		for k, j := range l.janelas {
			if agora.Sub(j.inicio) >= l.janela {
				delete(l.janelas, k)
			}
		}
	}

	j := l.janelas[chave]
	if j == nil || agora.Sub(j.inicio) >= l.janela {
		l.janelas[chave] = &janelaLimite{inicio: agora, n: 1}
		return true, 0
	}
	if j.n >= l.max {
		return false, l.janela - agora.Sub(j.inicio)
	}
	j.n++
	return true, 0
}

// ipCliente devolve o IP de quem chamou. X-Forwarded-For só é considerado
// quando a conexão vem de um proxy confiável; aí vale o endereço mais à
// direita que não seja outro proxy confiável.
func ipCliente(r *http.Request, confiaveis []netip.Prefix) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	remoto, err := netip.ParseAddr(host)
	if err != nil || !confiavel(remoto, confiaveis) {
		return host
	}

	partes := strings.Split(r.Header.Get("X-Forwarded-For"), ",")
	for i := len(partes) - 1; i >= 0; i-- {
		ip, err := netip.ParseAddr(strings.TrimSpace(partes[i]))
		if err != nil {
			break
		}
		if !confiavel(ip, confiaveis) {
			return ip.String()
		}
	}
	return host
}

func confiavel(ip netip.Addr, prefixos []netip.Prefix) bool {
	ip = ip.Unmap()
	for _, p := range prefixos {
		if p.Contains(ip) {
			return true
		}
	}
	return false
}
