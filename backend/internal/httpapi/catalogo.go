package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"manuais/backend/internal/catalogo"
	"manuais/backend/internal/db"
)

const (
	anoMin = 1900
	anoMax = 2100
	// Mais palavras do que isso não melhora a busca e encarece a consulta.
	maxTermos = 8
	// Semelhança mínima de trigramas para uma palavra casar. O padrão do
	// pg_trgm (0,6) rejeita uma letra trocada no meio de palavra longa
	// ("volksvagen" dá 0,57).
	semelhancaMinima = 0.45
)

// ----- utilitários -----

// lerJSON decodifica o corpo; em caso de erro já responde 400.
func lerJSON(w http.ResponseWriter, r *http.Request, destino any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	if err := json.NewDecoder(r.Body).Decode(destino); err != nil {
		escreverErro(w, http.StatusBadRequest, "requisicao_invalida", "Corpo da requisição inválido.")
		return false
	}
	return true
}

// idDaURL lê um parâmetro numérico do caminho; se não for número, responde 404.
func idDaURL(w http.ResponseWriter, r *http.Request, nome string) (int64, bool) {
	id, err := strconv.ParseInt(chi.URLParam(r, nome), 10, 64)
	if err != nil {
		naoEncontrado(w)
		return 0, false
	}
	return id, true
}

// idOpcional lê um filtro numérico da query string; ausente = nil.
func idOpcional(r *http.Request, nome string) (*int64, error) {
	valor := r.URL.Query().Get(nome)
	if valor == "" {
		return nil, nil
	}
	id, err := strconv.ParseInt(valor, 10, 64)
	if err != nil {
		return nil, err
	}
	return &id, nil
}

func naoEncontrado(w http.ResponseWriter) {
	escreverErro(w, http.StatusNotFound, "nao_encontrado", "Registro não encontrado.")
}

func validacao(w http.ResponseWriter, mensagem string) {
	escreverErro(w, http.StatusUnprocessableEntity, "validacao", mensagem)
}

// erroDeEscrita traduz erros do catálogo e do Postgres para a resposta HTTP.
// excluindo muda o sentido da violação de chave estrangeira.
func erroDeEscrita(w http.ResponseWriter, err error, excluindo bool) {
	var ev catalogo.ErroValidacao
	var pgErr *pgconn.PgError
	switch {
	case errors.As(err, &ev):
		validacao(w, ev.Error())
	case errors.Is(err, catalogo.ErrNaoEncontrado), errors.Is(err, pgx.ErrNoRows):
		naoEncontrado(w)
	case errors.As(err, &pgErr) && pgErr.Code == "23505":
		escreverErro(w, http.StatusConflict, "conflito", "Já existe um registro igual.")
	case errors.As(err, &pgErr) && pgErr.Code == "23503" && excluindo:
		escreverErro(w, http.StatusConflict, "em_uso", "O registro está em uso e não pode ser excluído.")
	case errors.As(err, &pgErr) && pgErr.Code == "23503":
		escreverErro(w, http.StatusUnprocessableEntity, "referencia_invalida", "Um dos registros informados não existe.")
	case errors.As(err, &pgErr) && pgErr.Code == "23514":
		validacao(w, "Dados inválidos.")
	default:
		erroInterno(w, "escrita no catálogo", err)
	}
}

// excluir é o handler comum de DELETE: fn devolve quantas linhas apagou.
func (d Deps) excluir(fn func(q *db.Queries, r *http.Request, id int64) (int64, error)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, ok := idDaURL(w, r, "id")
		if !ok {
			return
		}
		err := d.Catalogo.AlterarCadastro(r.Context(), func(q *db.Queries) error {
			n, err := fn(q, r, id)
			if err == nil && n == 0 {
				return catalogo.ErrNaoEncontrado
			}
			return err
		})
		if err != nil {
			erroDeEscrita(w, err, true)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

// ----- marcas -----

func (d Deps) listarMarcas(w http.ResponseWriter, r *http.Request) {
	marcas, err := d.Q.ListarMarcas(r.Context())
	if err != nil {
		erroInterno(w, "listar marcas", err)
		return
	}
	escreverJSON(w, http.StatusOK, marcas)
}

// salvarMarca atende POST (sem {id}) e PUT (com {id}).
func (d Deps) salvarMarca(w http.ResponseWriter, r *http.Request) {
	var e struct {
		Nome string `json:"nome"`
	}
	if !lerJSON(w, r, &e) {
		return
	}
	e.Nome = strings.TrimSpace(e.Nome)
	if e.Nome == "" {
		validacao(w, "O nome é obrigatório.")
		return
	}

	var marca db.Marca
	status := http.StatusCreated
	err := d.Catalogo.AlterarCadastro(r.Context(), func(q *db.Queries) (err error) {
		if chi.URLParam(r, "id") == "" {
			marca, err = q.CriarMarca(r.Context(), e.Nome)
			return err
		}
		id, ok := idDaURLSemResposta(r, "id")
		if !ok {
			return catalogo.ErrNaoEncontrado
		}
		status = http.StatusOK
		marca, err = q.AtualizarMarca(r.Context(), db.AtualizarMarcaParams{ID: id, Nome: e.Nome})
		return err
	})
	if err != nil {
		erroDeEscrita(w, err, false)
		return
	}
	escreverJSON(w, status, marca)
}

func idDaURLSemResposta(r *http.Request, nome string) (int64, bool) {
	id, err := strconv.ParseInt(chi.URLParam(r, nome), 10, 64)
	return id, err == nil
}

// ----- modelos -----

func (d Deps) listarModelos(w http.ResponseWriter, r *http.Request) {
	marcaID, err := idOpcional(r, "marca_id")
	if err != nil {
		escreverErro(w, http.StatusBadRequest, "requisicao_invalida", "marca_id inválido.")
		return
	}
	modelos, err := d.Q.ListarModelos(r.Context(), marcaID)
	if err != nil {
		erroInterno(w, "listar modelos", err)
		return
	}
	escreverJSON(w, http.StatusOK, modelos)
}

func (d Deps) salvarModelo(w http.ResponseWriter, r *http.Request) {
	var e struct {
		MarcaID int64  `json:"marca_id"`
		Nome    string `json:"nome"`
	}
	if !lerJSON(w, r, &e) {
		return
	}
	e.Nome = strings.TrimSpace(e.Nome)
	if e.Nome == "" || e.MarcaID == 0 {
		validacao(w, "Marca e nome são obrigatórios.")
		return
	}

	var modelo db.Modelo
	status := http.StatusCreated
	err := d.Catalogo.AlterarCadastro(r.Context(), func(q *db.Queries) (err error) {
		if chi.URLParam(r, "id") == "" {
			modelo, err = q.CriarModelo(r.Context(), db.CriarModeloParams{MarcaID: e.MarcaID, Nome: e.Nome})
			return err
		}
		id, ok := idDaURLSemResposta(r, "id")
		if !ok {
			return catalogo.ErrNaoEncontrado
		}
		status = http.StatusOK
		modelo, err = q.AtualizarModelo(r.Context(), db.AtualizarModeloParams{ID: id, MarcaID: e.MarcaID, Nome: e.Nome})
		return err
	})
	if err != nil {
		erroDeEscrita(w, err, false)
		return
	}
	escreverJSON(w, status, modelo)
}

// ----- motores -----

func (d Deps) listarMotores(w http.ResponseWriter, r *http.Request) {
	motores, err := d.Q.ListarMotores(r.Context())
	if err != nil {
		erroInterno(w, "listar motores", err)
		return
	}
	escreverJSON(w, http.StatusOK, motores)
}

func (d Deps) salvarMotor(w http.ResponseWriter, r *http.Request) {
	var e struct {
		Codigo    string `json:"codigo"`
		Descricao string `json:"descricao"`
	}
	if !lerJSON(w, r, &e) {
		return
	}
	e.Codigo = strings.TrimSpace(e.Codigo)
	e.Descricao = strings.TrimSpace(e.Descricao)
	if e.Codigo == "" {
		validacao(w, "O código do motor é obrigatório.")
		return
	}

	var motor db.Motor
	status := http.StatusCreated
	err := d.Catalogo.AlterarCadastro(r.Context(), func(q *db.Queries) (err error) {
		if chi.URLParam(r, "id") == "" {
			motor, err = q.CriarMotor(r.Context(), db.CriarMotorParams{Codigo: e.Codigo, Descricao: e.Descricao})
			return err
		}
		id, ok := idDaURLSemResposta(r, "id")
		if !ok {
			return catalogo.ErrNaoEncontrado
		}
		status = http.StatusOK
		motor, err = q.AtualizarMotor(r.Context(), db.AtualizarMotorParams{ID: id, Codigo: e.Codigo, Descricao: e.Descricao})
		return err
	})
	if err != nil {
		erroDeEscrita(w, err, false)
		return
	}
	escreverJSON(w, status, motor)
}

// ----- veículos -----

func (d Deps) listarVeiculos(w http.ResponseWriter, r *http.Request) {
	modeloID, err1 := idOpcional(r, "modelo_id")
	motorID, err2 := idOpcional(r, "motor_id")
	if err1 != nil || err2 != nil {
		escreverErro(w, http.StatusBadRequest, "requisicao_invalida", "Filtro inválido.")
		return
	}
	veiculos, err := d.Q.ListarVeiculos(r.Context(), db.ListarVeiculosParams{ModeloID: modeloID, MotorID: motorID})
	if err != nil {
		erroInterno(w, "listar veículos", err)
		return
	}
	escreverJSON(w, http.StatusOK, veiculos)
}

func anoValido(ano *int16) bool {
	return ano == nil || (*ano >= anoMin && *ano <= anoMax)
}

func (d Deps) salvarVeiculo(w http.ResponseWriter, r *http.Request) {
	var e struct {
		ModeloID  int64  `json:"modelo_id"`
		MotorID   *int64 `json:"motor_id"`
		AnoInicio *int16 `json:"ano_inicio"`
		AnoFim    *int16 `json:"ano_fim"`
	}
	if !lerJSON(w, r, &e) {
		return
	}
	switch {
	case e.ModeloID == 0:
		validacao(w, "O modelo é obrigatório.")
		return
	case !anoValido(e.AnoInicio) || !anoValido(e.AnoFim):
		validacao(w, "Ano fora do intervalo aceito.")
		return
	case e.AnoInicio != nil && e.AnoFim != nil && *e.AnoFim < *e.AnoInicio:
		validacao(w, "O ano final não pode ser menor que o inicial.")
		return
	}

	var id int64
	status := http.StatusCreated
	err := d.Catalogo.AlterarCadastro(r.Context(), func(q *db.Queries) (err error) {
		if chi.URLParam(r, "id") == "" {
			id, err = q.CriarVeiculo(r.Context(), db.CriarVeiculoParams{
				ModeloID: e.ModeloID, MotorID: e.MotorID, AnoInicio: e.AnoInicio, AnoFim: e.AnoFim,
			})
			return err
		}
		var ok bool
		if id, ok = idDaURLSemResposta(r, "id"); !ok {
			return catalogo.ErrNaoEncontrado
		}
		status = http.StatusOK
		n, err := q.AtualizarVeiculo(r.Context(), db.AtualizarVeiculoParams{
			ID: id, ModeloID: e.ModeloID, MotorID: e.MotorID, AnoInicio: e.AnoInicio, AnoFim: e.AnoFim,
		})
		if err == nil && n == 0 {
			return catalogo.ErrNaoEncontrado
		}
		return err
	})
	if err != nil {
		erroDeEscrita(w, err, false)
		return
	}
	escreverJSON(w, status, map[string]int64{"id": id})
}

// ----- documentos -----

// termosDaBusca quebra o texto em palavras e tira os curingas do LIKE.
func termosDaBusca(q string) []string {
	q = strings.NewReplacer("%", " ", "_", " ", `\`, " ").Replace(q)
	termos := strings.Fields(q)
	if len(termos) > maxTermos {
		termos = termos[:maxTermos]
	}
	if termos == nil {
		termos = []string{}
	}
	return termos
}

func (d Deps) listarDocumentos(soFavoritos bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		marcaID, err1 := idOpcional(r, "marca_id")
		modeloID, err2 := idOpcional(r, "modelo_id")
		motorID, err3 := idOpcional(r, "motor_id")
		if err1 != nil || err2 != nil || err3 != nil {
			escreverErro(w, http.StatusBadRequest, "requisicao_invalida", "Filtro inválido.")
			return
		}
		var tipo *string
		if t := q.Get("tipo"); t != "" {
			tipo = &t
		}
		termos := termosDaBusca(q.Get("q"))
		// "%" ou "_" sozinhos não podem virar uma busca sem filtro.
		if len(termos) == 0 && strings.TrimSpace(q.Get("q")) != "" {
			escreverJSON(w, http.StatusOK, map[string]any{
				"itens": []db.ListarDocumentosRow{}, "total": 0, "pagina": 1, "por_pagina": porPagina,
			})
			return
		}
		pag := pagina(r)
		usuarioID := usuarioAtual(r.Context()).ID

		total, err := d.Q.ContarDocumentos(r.Context(), db.ContarDocumentosParams{
			UsuarioID: usuarioID, Tipo: tipo, SoFavoritos: soFavoritos,
			MarcaID: marcaID, ModeloID: modeloID, MotorID: motorID, Termos: termos,
			SemelhancaMinima: semelhancaMinima,
		})
		if err != nil {
			erroInterno(w, "contar documentos", err)
			return
		}
		itens, err := d.Q.ListarDocumentos(r.Context(), db.ListarDocumentosParams{
			UsuarioID: usuarioID, Tipo: tipo, SoFavoritos: soFavoritos,
			MarcaID: marcaID, ModeloID: modeloID, MotorID: motorID, Termos: termos,
			SemelhancaMinima: semelhancaMinima,
			Limite:           porPagina, Deslocamento: int32((pag - 1) * porPagina),
		})
		if err != nil {
			erroInterno(w, "listar documentos", err)
			return
		}
		escreverJSON(w, http.StatusOK, map[string]any{
			"itens": itens, "total": total, "pagina": pag, "por_pagina": porPagina,
		})
	}
}

func (d Deps) detalharDocumento(w http.ResponseWriter, r *http.Request) {
	id, ok := idDaURL(w, r, "id")
	if !ok {
		return
	}
	doc, err := d.Q.BuscarDocumento(r.Context(), db.BuscarDocumentoParams{ID: id, UsuarioID: usuarioAtual(r.Context()).ID})
	if errors.Is(err, pgx.ErrNoRows) {
		naoEncontrado(w)
		return
	}
	if err != nil {
		erroInterno(w, "buscar documento", err)
		return
	}
	veiculos, err := d.Q.ListarVeiculos(r.Context(), db.ListarVeiculosParams{DocumentoID: &id})
	if err != nil {
		erroInterno(w, "listar veículos do documento", err)
		return
	}
	motores, err := d.Q.ListarMotoresDoDocumento(r.Context(), id)
	if err != nil {
		erroInterno(w, "listar motores do documento", err)
		return
	}
	escreverJSON(w, http.StatusOK, struct {
		db.BuscarDocumentoRow
		Veiculos []db.ListarVeiculosRow `json:"veiculos"`
		Motores  []db.Motor             `json:"motores"`
	}{doc, veiculos, motores})
}

func (d Deps) criarDocumento(w http.ResponseWriter, r *http.Request) {
	var e catalogo.Documento
	if !lerJSON(w, r, &e) {
		return
	}
	id, err := d.Catalogo.CriarDocumento(r.Context(), e)
	if err != nil {
		erroDeEscrita(w, err, false)
		return
	}
	escreverJSON(w, http.StatusCreated, map[string]int64{"id": id})
}

func (d Deps) atualizarDocumento(w http.ResponseWriter, r *http.Request) {
	id, ok := idDaURL(w, r, "id")
	if !ok {
		return
	}
	var e catalogo.Documento
	if !lerJSON(w, r, &e) {
		return
	}
	if err := d.Catalogo.AtualizarDocumento(r.Context(), id, e); err != nil {
		erroDeEscrita(w, err, false)
		return
	}
	escreverJSON(w, http.StatusOK, map[string]int64{"id": id})
}

func (d Deps) excluirDocumento(w http.ResponseWriter, r *http.Request) {
	id, ok := idDaURL(w, r, "id")
	if !ok {
		return
	}
	if err := d.Catalogo.ExcluirDocumento(r.Context(), id); err != nil {
		erroDeEscrita(w, err, true)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ----- favoritos -----

func (d Deps) definirFavorito(favoritar bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, ok := idDaURL(w, r, "documento_id")
		if !ok {
			return
		}
		usuarioID := usuarioAtual(r.Context()).ID
		var err error
		if favoritar {
			err = d.Q.AdicionarFavorito(r.Context(), db.AdicionarFavoritoParams{UsuarioID: usuarioID, DocumentoID: id})
		} else {
			err = d.Q.RemoverFavorito(r.Context(), db.RemoverFavoritoParams{UsuarioID: usuarioID, DocumentoID: id})
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23503" {
			naoEncontrado(w)
			return
		}
		if err != nil {
			erroInterno(w, "definir favorito", err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}
