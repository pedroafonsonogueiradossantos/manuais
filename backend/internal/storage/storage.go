// Package storage abstrai onde os arquivos dos manuais ficam guardados.
// Nada fora deste pacote (e dos subpacotes) deve conhecer a API do Google Drive:
// uma futura implementação para R2/S3 só precisa satisfazer FileStorage.
package storage

import (
	"context"
	"errors"
	"io"
	"strings"
	"time"
)

var (
	ErrNaoEncontrado     = errors.New("arquivo não encontrado no storage")
	ErrIntervaloInvalido = errors.New("intervalo de bytes inválido")
	ErrNaoConfigurado    = errors.New("storage não configurado")
)

type FileInfo struct {
	ID string
	// Nome do arquivo e caminho das pastas a partir da raiz (ex.: "VW/Gol").
	Nome         string
	Caminho      string
	MimeType     string
	TamanhoBytes int64
	// MD5 em hexadecimal; vazio quando o storage não informa.
	MD5          string
	ModificadoEm time.Time
}

// Conteudo é o corpo de um arquivo (ou de um trecho dele) em streaming.
type Conteudo struct {
	Corpo io.ReadCloser
	// Tamanho do corpo em bytes; -1 quando desconhecido.
	Tamanho int64
	// Intervalo é o Content-Range quando o corpo é parcial; vazio = arquivo inteiro.
	Intervalo string
}

type FileStorage interface {
	// List devolve todos os arquivos catalogáveis (PDFs e imagens), recursivamente.
	List(ctx context.Context) ([]FileInfo, error)
	// Open abre o arquivo para leitura. intervalo é um cabeçalho HTTP Range
	// ("bytes=100-") ou vazio para o arquivo inteiro. Quem chama fecha o Corpo.
	Open(ctx context.Context, fileID, intervalo string) (*Conteudo, error)
}

// Catalogavel diz se o tipo de arquivo entra no catálogo.
func Catalogavel(mimeType string) bool {
	return mimeType == "application/pdf" || strings.HasPrefix(mimeType, "image/")
}

// NaoConfigurado é usado quando as variáveis do storage não foram definidas:
// a API sobe, mas as rotas de arquivo respondem com erro.
type NaoConfigurado struct{}

func (NaoConfigurado) List(context.Context) ([]FileInfo, error) { return nil, ErrNaoConfigurado }

func (NaoConfigurado) Open(context.Context, string, string) (*Conteudo, error) {
	return nil, ErrNaoConfigurado
}
