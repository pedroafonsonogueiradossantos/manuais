// Package drive implementa storage.FileStorage sobre o Google Drive, com uma
// service account que tem acesso de leitura à pasta raiz.
package drive

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"path"
	"time"

	gdrive "google.golang.org/api/drive/v3"
	"google.golang.org/api/googleapi"
	"google.golang.org/api/option"

	"manuais/backend/internal/storage"
)

const (
	mimePasta   = "application/vnd.google-apps.folder"
	camposLista = "nextPageToken, files(id, name, mimeType, size, md5Checksum, modifiedTime)"
)

type Storage struct {
	svc  *gdrive.Service
	raiz string
}

// Novo usa as credenciais padrão do Google (GOOGLE_APPLICATION_CREDENTIALS).
// opts existe para os testes apontarem para um servidor falso.
func Novo(ctx context.Context, pastaRaizID string, opts ...option.ClientOption) (*Storage, error) {
	if pastaRaizID == "" {
		return nil, errors.New("ID da pasta raiz do Drive é obrigatório")
	}
	opts = append([]option.ClientOption{option.WithScopes(gdrive.DriveReadonlyScope)}, opts...)
	svc, err := gdrive.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("criar cliente do Drive: %w", err)
	}
	return &Storage{svc: svc, raiz: pastaRaizID}, nil
}

func (s *Storage) List(ctx context.Context) ([]storage.FileInfo, error) {
	type pasta struct{ id, caminho string }

	var arquivos []storage.FileInfo
	fila := []pasta{{id: s.raiz}}
	// Uma pasta pode aparecer em mais de um lugar; visita cada uma só uma vez.
	visitadas := map[string]bool{s.raiz: true}

	for len(fila) > 0 {
		atual := fila[0]
		fila = fila[1:]

		err := s.svc.Files.List().
			Q(fmt.Sprintf("'%s' in parents and trashed = false", atual.id)).
			Fields(camposLista).
			PageSize(1000).
			// Inofensivo em "Meu Drive", necessário em drives compartilhados.
			SupportsAllDrives(true).
			IncludeItemsFromAllDrives(true).
			Pages(ctx, func(pagina *gdrive.FileList) error {
				for _, f := range pagina.Files {
					switch {
					case f.MimeType == mimePasta:
						if !visitadas[f.Id] {
							visitadas[f.Id] = true
							fila = append(fila, pasta{id: f.Id, caminho: path.Join(atual.caminho, f.Name)})
						}
					case storage.Catalogavel(f.MimeType):
						// Erro de formato vira data zero; não vale derrubar a listagem.
						modificado, _ := time.Parse(time.RFC3339, f.ModifiedTime)
						arquivos = append(arquivos, storage.FileInfo{
							ID:           f.Id,
							Nome:         f.Name,
							Caminho:      atual.caminho,
							MimeType:     f.MimeType,
							TamanhoBytes: f.Size,
							MD5:          f.Md5Checksum,
							ModificadoEm: modificado,
						})
					}
				}
				return nil
			})
		if err != nil {
			return nil, fmt.Errorf("listar pasta %q do Drive: %w", atual.caminho, err)
		}
	}
	return arquivos, nil
}

func (s *Storage) Open(ctx context.Context, fileID, intervalo string) (*storage.Conteudo, error) {
	chamada := s.svc.Files.Get(fileID).SupportsAllDrives(true).Context(ctx)
	if intervalo != "" {
		chamada.Header().Set("Range", intervalo)
	}

	resp, err := chamada.Download()
	if err != nil {
		var gerr *googleapi.Error
		if errors.As(err, &gerr) {
			switch gerr.Code {
			case http.StatusNotFound:
				return nil, storage.ErrNaoEncontrado
			case http.StatusRequestedRangeNotSatisfiable:
				return nil, storage.ErrIntervaloInvalido
			}
		}
		return nil, fmt.Errorf("baixar arquivo do Drive: %w", err)
	}

	c := &storage.Conteudo{Corpo: resp.Body, Tamanho: resp.ContentLength}
	if resp.StatusCode == http.StatusPartialContent {
		c.Intervalo = resp.Header.Get("Content-Range")
	}
	return c, nil
}
