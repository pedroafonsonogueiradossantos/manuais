package httpapi

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

// req faz uma chamada JSON autenticada e decodifica a resposta em destino
// (se não for nil). Devolve o status.
func (a *ambienteArquivos) req(t *testing.T, metodo, caminho string, usuarioID int64, corpo, destino any) int {
	t.Helper()
	var leitor *bytes.Reader
	if corpo != nil {
		b, err := json.Marshal(corpo)
		if err != nil {
			t.Fatal(err)
		}
		leitor = bytes.NewReader(b)
	} else {
		leitor = bytes.NewReader(nil)
	}
	r := httptest.NewRequest(metodo, caminho, leitor)
	r.Header.Set("Authorization", "Bearer "+a.tokenDe(t, usuarioID))
	rec := httptest.NewRecorder()
	a.router.ServeHTTP(rec, r)
	if destino != nil && rec.Body.Len() > 0 {
		if err := json.Unmarshal(rec.Body.Bytes(), destino); err != nil {
			t.Fatalf("%s %s: resposta não é JSON: %v (%s)", metodo, caminho, err, rec.Body)
		}
	}
	return rec.Code
}

type comID struct {
	ID int64 `json:"id"`
}

// criar faz POST e exige 201, devolvendo o id.
func (a *ambienteArquivos) criar(t *testing.T, caminho string, corpo any) int64 {
	t.Helper()
	var r comID
	var bruto json.RawMessage
	status := a.req(t, http.MethodPost, caminho, idAdmin, corpo, &bruto)
	if status != http.StatusCreated {
		t.Fatalf("POST %s: status %d: %s", caminho, status, bruto)
	}
	json.Unmarshal(bruto, &r)
	if r.ID == 0 {
		t.Fatalf("POST %s: resposta sem id: %s", caminho, bruto)
	}
	return r.ID
}

type erroJSON struct {
	Erro struct {
		Codigo string `json:"codigo"`
	} `json:"erro"`
}

// exigirErro faz a chamada e confere status e código de erro.
func (a *ambienteArquivos) exigirErro(t *testing.T, metodo, caminho string, usuarioID int64, corpo any, status int, codigo string) {
	t.Helper()
	var e erroJSON
	got := a.req(t, metodo, caminho, usuarioID, corpo, &e)
	if got != status || e.Erro.Codigo != codigo {
		t.Errorf("%s %s: status %d código %q, quero %d %q", metodo, caminho, got, e.Erro.Codigo, status, codigo)
	}
}

type catalogoTeste struct {
	*ambienteArquivos
	vw, fiat           int64
	gol, uno           int64
	ea111              int64
	veiculoGol         int64
	veiculoUno         int64
	docGol, docInjecao int64
	docUno             int64
}

// novoCatalogo monta: VW Gol (EA111 1.6 8v, 1995-2005) e Fiat Uno; três
// documentos, um deles ligado só ao motor.
func novoCatalogo(t *testing.T) *catalogoTeste {
	t.Helper()
	c := &catalogoTeste{ambienteArquivos: novoAmbienteArquivos(t)}
	c.vw = c.criar(t, "/admin/marcas", map[string]any{"nome": "VW"})
	c.fiat = c.criar(t, "/admin/marcas", map[string]any{"nome": "Fiat"})
	c.gol = c.criar(t, "/admin/modelos", map[string]any{"marca_id": c.vw, "nome": "Gol"})
	c.uno = c.criar(t, "/admin/modelos", map[string]any{"marca_id": c.fiat, "nome": "Uno"})
	c.ea111 = c.criar(t, "/admin/motores", map[string]any{"codigo": "EA111", "descricao": "1.6 8v"})
	c.veiculoGol = c.criar(t, "/admin/veiculos", map[string]any{"modelo_id": c.gol, "motor_id": c.ea111, "ano_inicio": 1995, "ano_fim": 2005})
	c.veiculoUno = c.criar(t, "/admin/veiculos", map[string]any{"modelo_id": c.uno})

	c.docGol = c.criar(t, "/admin/documentos", map[string]any{
		"titulo": "Manual de serviço", "tipo": "manual_servico", "storage_file_id": "gol",
		"veiculo_ids": []int64{c.veiculoGol},
	})
	c.docInjecao = c.criar(t, "/admin/documentos", map[string]any{
		"titulo": "Diagrama da injeção", "tipo": "diagrama_eletrico", "storage_file_id": "foto",
		"motor_ids": []int64{c.ea111},
	})
	c.docUno = c.criar(t, "/admin/documentos", map[string]any{
		"titulo": "Parte elétrica", "tipo": "diagrama_eletrico", "storage_file_id": "uno",
		"veiculo_ids": []int64{c.veiculoUno},
	})
	return c
}

type listaDocumentos struct {
	Itens []struct {
		ID           int64   `json:"id"`
		Titulo       string  `json:"titulo"`
		Tipo         string  `json:"tipo"`
		MimeType     string  `json:"mime_type"`
		TamanhoBytes int64   `json:"tamanho_bytes"`
		ArquivoMd5   *string `json:"arquivo_md5"`
		Favorito     bool    `json:"favorito"`
		Indisponivel bool    `json:"indisponivel"`
	} `json:"itens"`
	Total     int64 `json:"total"`
	Pagina    int   `json:"pagina"`
	PorPagina int   `json:"por_pagina"`
}

func (c *catalogoTeste) buscar(t *testing.T, caminho string, usuarioID int64) (ids map[int64]bool, lista listaDocumentos) {
	t.Helper()
	if status := c.req(t, http.MethodGet, caminho, usuarioID, nil, &lista); status != http.StatusOK {
		t.Fatalf("GET %s: status %d", caminho, status)
	}
	ids = map[int64]bool{}
	for _, d := range lista.Itens {
		ids[d.ID] = true
	}
	if int64(len(lista.Itens)) != lista.Total {
		t.Errorf("GET %s: %d itens mas total %d", caminho, len(lista.Itens), lista.Total)
	}
	return ids, lista
}

func (c *catalogoTeste) exigirDocs(t *testing.T, caminho string, quero ...int64) {
	t.Helper()
	ids, _ := c.buscar(t, caminho, idMecanico)
	ok := len(ids) == len(quero)
	for _, id := range quero {
		ok = ok && ids[id]
	}
	if !ok {
		t.Errorf("GET %s = %v, quero %v", caminho, ids, quero)
	}
}

func TestBuscaDeDocumentos(t *testing.T) {
	c := novoCatalogo(t)
	q := func(texto string) string { return "/documentos?q=" + url.QueryEscape(texto) }

	c.exigirDocs(t, "/documentos", c.docGol, c.docInjecao, c.docUno)

	// Por modelo: alcança também o documento ligado só ao motor do Gol.
	c.exigirDocs(t, q("gol"), c.docGol, c.docInjecao)
	// Por código e descrição do motor.
	c.exigirDocs(t, q("ea111"), c.docGol, c.docInjecao)
	c.exigirDocs(t, q("8v"), c.docGol, c.docInjecao)
	// Por marca e por título, sem acento e sem maiúsculas.
	c.exigirDocs(t, q("FIAT"), c.docUno)
	c.exigirDocs(t, q("injecao"), c.docInjecao)
	c.exigirDocs(t, q("serviço"), c.docGol)
	// Erro de digitação.
	c.exigirDocs(t, q("diagrma"), c.docInjecao)
	c.exigirDocs(t, q("eletrca"), c.docUno)
	c.exigirDocs(t, q("injeçao gol"), c.docInjecao)
	// Todas as palavras precisam casar.
	c.exigirDocs(t, q("gol uno"))
	c.exigirDocs(t, q("xyzxyz"))
	// Curingas do LIKE não podem virar "casa com tudo".
	c.exigirDocs(t, q("%"))
	c.exigirDocs(t, q("_"))

	// Filtros.
	c.exigirDocs(t, fmt.Sprintf("/documentos?marca_id=%d", c.fiat), c.docUno)
	c.exigirDocs(t, fmt.Sprintf("/documentos?marca_id=%d", c.vw), c.docGol, c.docInjecao)
	c.exigirDocs(t, fmt.Sprintf("/documentos?modelo_id=%d", c.gol), c.docGol, c.docInjecao)
	c.exigirDocs(t, fmt.Sprintf("/documentos?motor_id=%d", c.ea111), c.docGol, c.docInjecao)
	c.exigirDocs(t, "/documentos?tipo=diagrama_eletrico", c.docInjecao, c.docUno)
	c.exigirDocs(t, fmt.Sprintf("/documentos?tipo=diagrama_eletrico&marca_id=%d&q=eletrica", c.fiat), c.docUno)

	_, lista := c.buscar(t, q("serviço"), idMecanico)
	d := lista.Itens[0]
	if d.Titulo != "Manual de serviço" || d.Tipo != "manual_servico" || d.MimeType != "application/pdf" ||
		d.TamanhoBytes != 10 || d.ArquivoMd5 == nil || *d.ArquivoMd5 != "md5gol" || d.Favorito || d.Indisponivel {
		t.Errorf("item = %+v", d)
	}
	if lista.Pagina != 1 || lista.PorPagina != porPagina {
		t.Errorf("paginação = %d/%d", lista.Pagina, lista.PorPagina)
	}

	c.exigirErro(t, http.MethodGet, "/documentos?marca_id=abc", idMecanico, nil, http.StatusBadRequest, "requisicao_invalida")
}

func TestBuscaAcompanhaMudancasNoCadastro(t *testing.T) {
	c := novoCatalogo(t)

	// Renomear a marca reflete na busca.
	if status := c.req(t, http.MethodPut, fmt.Sprintf("/admin/marcas/%d", c.vw), idAdmin, map[string]any{"nome": "Volkswagen"}, nil); status != http.StatusOK {
		t.Fatalf("renomear marca: status %d", status)
	}
	c.exigirDocs(t, "/documentos?q=volkswagen", c.docGol, c.docInjecao)
	c.exigirDocs(t, "/documentos?q=vw")
	// Letra trocada no meio de uma palavra longa ainda encontra.
	c.exigirDocs(t, "/documentos?q=volksvagen+gol+8v", c.docGol, c.docInjecao)

	// Novo veículo com o mesmo motor: o documento do motor passa a aparecer nele.
	saveiro := c.criar(t, "/admin/modelos", map[string]any{"marca_id": c.vw, "nome": "Saveiro"})
	c.criar(t, "/admin/veiculos", map[string]any{"modelo_id": saveiro, "motor_id": c.ea111})
	c.exigirDocs(t, "/documentos?q=saveiro", c.docInjecao)
	c.exigirDocs(t, fmt.Sprintf("/documentos?modelo_id=%d", saveiro), c.docInjecao)

	// Editar o documento troca título e associações.
	status := c.req(t, http.MethodPut, fmt.Sprintf("/admin/documentos/%d", c.docUno), idAdmin, map[string]any{
		"titulo": "Esquema do alternador", "tipo": "outro", "veiculo_ids": []int64{c.veiculoGol},
	}, nil)
	if status != http.StatusOK {
		t.Fatalf("editar documento: status %d", status)
	}
	c.exigirDocs(t, "/documentos?q=alternador", c.docUno)
	c.exigirDocs(t, "/documentos?q=uno")
	c.exigirDocs(t, fmt.Sprintf("/documentos?modelo_id=%d", c.gol), c.docGol, c.docInjecao, c.docUno)
}

func TestDetalheDoDocumento(t *testing.T) {
	c := novoCatalogo(t)

	var d struct {
		ID           int64  `json:"id"`
		Titulo       string `json:"titulo"`
		ArquivoNome  string `json:"arquivo_nome"`
		TamanhoBytes int64  `json:"tamanho_bytes"`
		Veiculos     []struct {
			ID          int64   `json:"id"`
			MarcaNome   string  `json:"marca_nome"`
			ModeloNome  string  `json:"modelo_nome"`
			MotorCodigo *string `json:"motor_codigo"`
			AnoInicio   *int    `json:"ano_inicio"`
			AnoFim      *int    `json:"ano_fim"`
		} `json:"veiculos"`
		Motores []struct {
			ID     int64  `json:"id"`
			Codigo string `json:"codigo"`
		} `json:"motores"`
	}
	if status := c.req(t, http.MethodGet, fmt.Sprintf("/documentos/%d", c.docGol), idMecanico, nil, &d); status != http.StatusOK {
		t.Fatalf("status %d", status)
	}
	if d.ID != c.docGol || d.Titulo != "Manual de serviço" || d.ArquivoNome != "Gol 1.6.pdf" || d.TamanhoBytes != 10 {
		t.Errorf("documento = %+v", d)
	}
	if len(d.Veiculos) != 1 || d.Veiculos[0].MarcaNome != "VW" || d.Veiculos[0].ModeloNome != "Gol" ||
		d.Veiculos[0].MotorCodigo == nil || *d.Veiculos[0].MotorCodigo != "EA111" ||
		d.Veiculos[0].AnoInicio == nil || *d.Veiculos[0].AnoInicio != 1995 {
		t.Errorf("veiculos = %+v", d.Veiculos)
	}
	if d.Motores == nil || len(d.Motores) != 0 {
		t.Errorf("motores deveria ser lista vazia, veio %+v", d.Motores)
	}

	d.Veiculos, d.Motores = nil, nil
	c.req(t, http.MethodGet, fmt.Sprintf("/documentos/%d", c.docInjecao), idMecanico, nil, &d)
	if len(d.Motores) != 1 || d.Motores[0].Codigo != "EA111" || len(d.Veiculos) != 0 {
		t.Errorf("doc do motor: veiculos=%+v motores=%+v", d.Veiculos, d.Motores)
	}

	c.exigirErro(t, http.MethodGet, "/documentos/999999", idMecanico, nil, http.StatusNotFound, "nao_encontrado")
}

func TestListasDoCadastro(t *testing.T) {
	c := novoCatalogo(t)

	var marcas []struct {
		ID   int64  `json:"id"`
		Nome string `json:"nome"`
	}
	c.req(t, http.MethodGet, "/marcas", idMecanico, nil, &marcas)
	if len(marcas) != 2 || marcas[0].Nome != "Fiat" || marcas[1].Nome != "VW" {
		t.Errorf("marcas = %+v", marcas)
	}

	var modelos []struct {
		ID        int64  `json:"id"`
		Nome      string `json:"nome"`
		MarcaNome string `json:"marca_nome"`
	}
	c.req(t, http.MethodGet, fmt.Sprintf("/modelos?marca_id=%d", c.vw), idMecanico, nil, &modelos)
	if len(modelos) != 1 || modelos[0].Nome != "Gol" || modelos[0].MarcaNome != "VW" {
		t.Errorf("modelos da VW = %+v", modelos)
	}
	modelos = nil
	c.req(t, http.MethodGet, "/modelos", idMecanico, nil, &modelos)
	if len(modelos) != 2 {
		t.Errorf("todos os modelos = %+v", modelos)
	}

	var motores []struct {
		Codigo    string `json:"codigo"`
		Descricao string `json:"descricao"`
	}
	c.req(t, http.MethodGet, "/motores", idMecanico, nil, &motores)
	if len(motores) != 1 || motores[0].Codigo != "EA111" || motores[0].Descricao != "1.6 8v" {
		t.Errorf("motores = %+v", motores)
	}

	var veiculos []comID
	c.req(t, http.MethodGet, fmt.Sprintf("/veiculos?modelo_id=%d", c.gol), idMecanico, nil, &veiculos)
	if len(veiculos) != 1 || veiculos[0].ID != c.veiculoGol {
		t.Errorf("veículos do Gol = %+v", veiculos)
	}
}

func TestValidacaoEConflitosDoCadastro(t *testing.T) {
	c := novoCatalogo(t)
	const (
		post = http.MethodPost
		put  = http.MethodPut
		del  = http.MethodDelete
	)

	// Mecânico não escreve no catálogo.
	c.exigirErro(t, post, "/admin/marcas", idMecanico, map[string]any{"nome": "Ford"}, http.StatusForbidden, "sem_permissao")

	c.exigirErro(t, post, "/admin/marcas", idAdmin, map[string]any{"nome": "  "}, http.StatusUnprocessableEntity, "validacao")
	c.exigirErro(t, post, "/admin/marcas", idAdmin, map[string]any{"nome": "VW"}, http.StatusConflict, "conflito")
	c.exigirErro(t, post, "/admin/modelos", idAdmin, map[string]any{"marca_id": 999999, "nome": "X"}, http.StatusUnprocessableEntity, "referencia_invalida")
	c.exigirErro(t, post, "/admin/modelos", idAdmin, map[string]any{"marca_id": c.vw, "nome": "Gol"}, http.StatusConflict, "conflito")
	c.exigirErro(t, post, "/admin/motores", idAdmin, map[string]any{"codigo": ""}, http.StatusUnprocessableEntity, "validacao")
	c.exigirErro(t, post, "/admin/veiculos", idAdmin, map[string]any{"modelo_id": c.gol, "ano_inicio": 2010, "ano_fim": 2000}, http.StatusUnprocessableEntity, "validacao")
	c.exigirErro(t, post, "/admin/veiculos", idAdmin, map[string]any{"modelo_id": c.gol, "ano_inicio": 1700}, http.StatusUnprocessableEntity, "validacao")
	c.exigirErro(t, put, "/admin/marcas/999999", idAdmin, map[string]any{"nome": "X"}, http.StatusNotFound, "nao_encontrado")
	c.exigirErro(t, del, "/admin/marcas/999999", idAdmin, nil, http.StatusNotFound, "nao_encontrado")

	// Em uso não pode ser excluído.
	c.exigirErro(t, del, fmt.Sprintf("/admin/marcas/%d", c.vw), idAdmin, nil, http.StatusConflict, "em_uso")
	c.exigirErro(t, del, fmt.Sprintf("/admin/modelos/%d", c.gol), idAdmin, nil, http.StatusConflict, "em_uso")
	c.exigirErro(t, del, fmt.Sprintf("/admin/motores/%d", c.ea111), idAdmin, nil, http.StatusConflict, "em_uso")

	// Criar veículo igual devolve o mesmo id, sem erro.
	if id := c.criar(t, "/admin/veiculos", map[string]any{"modelo_id": c.uno}); id != c.veiculoUno {
		t.Errorf("veículo repetido: id %d, quero %d", id, c.veiculoUno)
	}

	doc := func(extra map[string]any) map[string]any {
		m := map[string]any{"titulo": "T", "tipo": "outro", "storage_file_id": "gol"}
		for k, v := range extra {
			m[k] = v
		}
		return m
	}
	c.exigirErro(t, post, "/admin/documentos", idAdmin, doc(nil), http.StatusConflict, "conflito") // arquivo já catalogado
	c.exigirErro(t, post, "/admin/documentos", idAdmin, doc(map[string]any{"storage_file_id": "nao-existe"}), http.StatusUnprocessableEntity, "referencia_invalida")
	c.exigirErro(t, post, "/admin/documentos", idAdmin, doc(map[string]any{"tipo": "revista"}), http.StatusUnprocessableEntity, "validacao")
	c.exigirErro(t, post, "/admin/documentos", idAdmin, doc(map[string]any{"titulo": ""}), http.StatusUnprocessableEntity, "validacao")
	c.exigirErro(t, put, "/admin/documentos/999999", idAdmin, doc(nil), http.StatusNotFound, "nao_encontrado")
	c.exigirErro(t, put, fmt.Sprintf("/admin/documentos/%d", c.docGol), idAdmin, doc(map[string]any{"veiculo_ids": []int64{999999}}), http.StatusUnprocessableEntity, "referencia_invalida")
	// A edição que falhou não pode ter apagado as associações antigas.
	c.exigirDocs(t, "/documentos?q=gol", c.docGol, c.docInjecao)

	// Corpo que não é JSON.
	r := httptest.NewRequest(post, "/admin/marcas", bytes.NewReader([]byte("{")))
	r.Header.Set("Authorization", "Bearer "+c.tokenDe(t, idAdmin))
	rec := httptest.NewRecorder()
	c.router.ServeHTTP(rec, r)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("JSON inválido: status %d, quero 400", rec.Code)
	}
}

func TestExcluirDocumentoDevolveArquivoParaAFila(t *testing.T) {
	c := novoCatalogo(t)
	if r := c.pendentes(t, ""); r.Total != 0 {
		t.Fatalf("fila deveria estar vazia, total %d", r.Total)
	}
	if status := c.req(t, http.MethodDelete, fmt.Sprintf("/admin/documentos/%d", c.docGol), idAdmin, nil, nil); status != http.StatusNoContent {
		t.Fatalf("excluir: status %d", status)
	}
	if r := c.pendentes(t, ""); !igual(ids(r), []string{"gol"}) {
		t.Errorf("fila depois de excluir = %v", ids(r))
	}
	c.exigirErro(t, http.MethodGet, fmt.Sprintf("/documentos/%d", c.docGol), idMecanico, nil, http.StatusNotFound, "nao_encontrado")

	// Sem documentos, o veículo e a marca podem ser excluídos em ordem.
	for _, caminho := range []string{
		fmt.Sprintf("/admin/veiculos/%d", c.veiculoGol),
		fmt.Sprintf("/admin/modelos/%d", c.gol),
	} {
		if status := c.req(t, http.MethodDelete, caminho, idAdmin, nil, nil); status != http.StatusNoContent {
			t.Errorf("DELETE %s: status %d", caminho, status)
		}
	}
}

func TestFavoritos(t *testing.T) {
	c := novoCatalogo(t)
	caminho := fmt.Sprintf("/favoritos/%d", c.docGol)

	// Favoritar duas vezes não dá erro.
	for i := 0; i < 2; i++ {
		if status := c.req(t, http.MethodPost, caminho, idMecanico, nil, nil); status != http.StatusNoContent {
			t.Fatalf("favoritar: status %d", status)
		}
	}

	ids, lista := c.buscar(t, "/favoritos", idMecanico)
	if len(ids) != 1 || !ids[c.docGol] || !lista.Itens[0].Favorito {
		t.Errorf("favoritos do mecânico = %+v", lista.Itens)
	}
	// Favoritos são por usuário.
	if ids, _ := c.buscar(t, "/favoritos", idAdmin); len(ids) != 0 {
		t.Errorf("favoritos do admin = %v", ids)
	}
	// A marca aparece na busca normal só para quem favoritou.
	_, lista = c.buscar(t, "/documentos?q=servico", idMecanico)
	if !lista.Itens[0].Favorito {
		t.Error("busca do mecânico deveria marcar favorito")
	}
	_, lista = c.buscar(t, "/documentos?q=servico", idAdmin)
	if lista.Itens[0].Favorito {
		t.Error("busca do admin não deveria marcar favorito")
	}

	if status := c.req(t, http.MethodDelete, caminho, idMecanico, nil, nil); status != http.StatusNoContent {
		t.Fatalf("desfavoritar: status %d", status)
	}
	if ids, _ := c.buscar(t, "/favoritos", idMecanico); len(ids) != 0 {
		t.Errorf("favoritos depois de remover = %v", ids)
	}

	c.exigirErro(t, http.MethodPost, "/favoritos/999999", idMecanico, nil, http.StatusNotFound, "nao_encontrado")
}
