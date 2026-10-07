// Comando api: servidor HTTP do catálogo de manuais.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"manuais/backend/internal/auth"
	"manuais/backend/internal/catalogo"
	"manuais/backend/internal/config"
	"manuais/backend/internal/db"
	"manuais/backend/internal/httpapi"
	"manuais/backend/internal/sinc"
	"manuais/backend/internal/storage"
	"manuais/backend/internal/storage/drive"
)

// Sessão longa: o app é usado offline e a revogação é feita pelo banco
// (usuario.ativo e senha_alterada_em), não pela expiração.
const validadeSessao = 30 * 24 * time.Hour

const intervaloSincronizacao = 30 * time.Minute

func main() {
	if err := executar(); err != nil {
		slog.Error("encerrando", "erro", err)
		os.Exit(1)
	}
}

func executar() error {
	cfg, err := config.Carregar(os.Getenv)
	if err != nil {
		return err
	}

	ctx, parar := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer parar()

	pool, err := db.Conectar(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	if err := db.Migrar(ctx, pool); err != nil {
		return err
	}

	var st storage.FileStorage = storage.NaoConfigurado{}
	if cfg.DrivePastaRaizID == "" {
		slog.Warn("DRIVE_ROOT_FOLDER_ID vazio: rotas de arquivo vão responder 503")
	} else {
		st, err = drive.Novo(ctx, cfg.DrivePastaRaizID)
		if err != nil {
			return err
		}
	}
	sincronizador := sinc.Novo(pool, st)
	if cfg.DrivePastaRaizID != "" {
		go sincronizarPeriodicamente(ctx, sincronizador)
	}

	// Sem WriteTimeout: o proxy de arquivos faz streaming de downloads longos.
	srv := &http.Server{
		Addr: cfg.HTTPAddr,
		Handler: httpapi.NovoRouter(httpapi.Deps{
			Banco:             pool,
			Usuarios:          db.New(pool),
			Tokens:            auth.NovoEmissor(cfg.JWTSecret, validadeSessao),
			ProxiesConfiaveis: cfg.ProxiesConfiaveis,
			Arquivos:          db.New(pool),
			Q:                 db.New(pool),
			Catalogo:          catalogo.Novo(pool),
			Storage:           st,
			Sincronizar:       sincronizador.Executar,
		}),
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}

	falha := make(chan error, 1)
	go func() {
		slog.Info("servidor no ar", "addr", cfg.HTTPAddr)
		falha <- srv.ListenAndServe()
	}()

	select {
	case err := <-falha:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
		return nil
	case <-ctx.Done():
	}

	slog.Info("desligando")
	ctxFim, cancelar := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancelar()
	return srv.Shutdown(ctxFim)
}

// sincronizarPeriodicamente roda uma vez ao subir e depois a cada intervalo,
// até o contexto ser cancelado.
func sincronizarPeriodicamente(ctx context.Context, s *sinc.Sincronizador) {
	relogio := time.NewTicker(intervaloSincronizacao)
	defer relogio.Stop()
	for {
		if res, err := s.Executar(ctx); err != nil {
			slog.Error("sincronização com o storage falhou", "erro", err)
		} else {
			slog.Info("storage sincronizado", "arquivos", res.Arquivos, "removidos", res.Removidos)
		}
		select {
		case <-ctx.Done():
			return
		case <-relogio.C:
		}
	}
}
