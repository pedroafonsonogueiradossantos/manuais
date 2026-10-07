package sinc

import (
	"context"
	"errors"
	"testing"
	"time"

	"manuais/backend/internal/db"
	"manuais/backend/internal/db/dbtest"
	"manuais/backend/internal/storage"
	"manuais/backend/internal/storage/fake"
)

func TestExecutar(t *testing.T) {
	tx := dbtest.Tx(t)
	ctx := context.Background()
	q := db.New(tx)
	st := fake.Novo()
	s := Novo(tx, st)

	mod := time.Date(2026, 3, 4, 5, 6, 7, 0, time.UTC)
	st.Por(storage.FileInfo{ID: "a", Nome: "a.pdf", Caminho: "VW", MimeType: "application/pdf", MD5: "m1", ModificadoEm: mod}, []byte("aaaa"))
	st.Por(storage.FileInfo{ID: "b", Nome: "b.jpg", MimeType: "image/jpeg", ModificadoEm: mod}, []byte("bb"))

	res, err := s.Executar(ctx)
	if err != nil {
		t.Fatalf("1ª execução: %v", err)
	}
	if res.Arquivos != 2 || res.Removidos != 0 {
		t.Errorf("resultado = %+v", res)
	}
	a, err := q.BuscarArquivoStorage(ctx, "a")
	if err != nil {
		t.Fatal(err)
	}
	if a.Nome != "a.pdf" || a.Caminho != "VW" || a.TamanhoBytes != 4 || a.Md5 == nil || *a.Md5 != "m1" ||
		a.ModificadoEm == nil || !a.ModificadoEm.Equal(mod) || a.RemovidoEm != nil {
		t.Errorf("a = %+v", a)
	}
	if b, _ := q.BuscarArquivoStorage(ctx, "b"); b.Md5 != nil {
		t.Errorf("md5 vazio deveria virar NULL, veio %q", *b.Md5)
	}

	// Marca "b" como ignorado: a sincronização não pode desfazer isso.
	if _, err := q.DefinirArquivoIgnorado(ctx, db.DefinirArquivoIgnoradoParams{StorageFileID: "b", Ignorado: true}); err != nil {
		t.Fatal(err)
	}

	// "a" muda de conteúdo e "b" some do storage.
	st.Por(storage.FileInfo{ID: "a", Nome: "a-v2.pdf", Caminho: "VW", MimeType: "application/pdf", MD5: "m2", ModificadoEm: mod.Add(time.Hour)}, []byte("aaaaaa"))
	st.Remover("b")
	res, err = s.Executar(ctx)
	if err != nil {
		t.Fatalf("2ª execução: %v", err)
	}
	if res.Arquivos != 1 || res.Removidos != 1 {
		t.Errorf("resultado = %+v", res)
	}
	a, _ = q.BuscarArquivoStorage(ctx, "a")
	if a.Nome != "a-v2.pdf" || *a.Md5 != "m2" || a.TamanhoBytes != 6 {
		t.Errorf("a não foi atualizado: %+v", a)
	}
	b, _ := q.BuscarArquivoStorage(ctx, "b")
	if b.RemovidoEm == nil || !b.Ignorado {
		t.Errorf("b deveria estar removido e continuar ignorado: %+v", b)
	}

	// "b" volta: deixa de estar removido.
	st.Por(storage.FileInfo{ID: "b", Nome: "b.jpg", MimeType: "image/jpeg", ModificadoEm: mod}, []byte("bb"))
	if _, err := s.Executar(ctx); err != nil {
		t.Fatal(err)
	}
	if b, _ := q.BuscarArquivoStorage(ctx, "b"); b.RemovidoEm != nil {
		t.Error("b voltou ao storage mas continua removido")
	}

	// Storage vazio (sem erro) marca tudo como removido.
	st.Remover("a")
	st.Remover("b")
	res, err = s.Executar(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if res.Arquivos != 0 || res.Removidos != 2 {
		t.Errorf("resultado com storage vazio = %+v", res)
	}
}

func TestExecutarNaoAlteraNadaSeAListagemFalha(t *testing.T) {
	tx := dbtest.Tx(t)
	ctx := context.Background()
	st := fake.Novo()
	s := Novo(tx, st)

	st.Por(storage.FileInfo{ID: "a", Nome: "a.pdf", MimeType: "application/pdf"}, []byte("a"))
	if _, err := s.Executar(ctx); err != nil {
		t.Fatal(err)
	}

	st.ErroList = errors.New("drive fora do ar")
	if _, err := s.Executar(ctx); err == nil {
		t.Fatal("quero erro quando a listagem falha")
	}
	if a, _ := db.New(tx).BuscarArquivoStorage(ctx, "a"); a.RemovidoEm != nil {
		t.Error("falha na listagem não pode marcar arquivos como removidos")
	}
}
