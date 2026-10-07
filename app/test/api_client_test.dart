import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/api/api_client.dart';

import 'apoio/adaptador_falso.dart';

void main() {
  late AdaptadorFalso adaptador;
  String? token;
  var expirou = 0;

  ApiClient criar(Future<ResponseBody> Function(RequestOptions) responder) {
    adaptador = AdaptadorFalso(responder);
    return ApiClient(
      baseUrl: 'http://api.teste',
      token: () => token,
      aoNaoAutenticado: () => expirou++,
      adaptador: adaptador,
    );
  }

  setUp(() {
    token = null;
    expirou = 0;
  });

  test('login devolve token e usuário', () async {
    final api = criar(
      (_) async => respostaJson(200, {
        'token': 'abc',
        'expira_em': '2026-11-01T00:00:00Z',
        'usuario': usuarioJson,
      }),
    );

    final r = await api.login('ana@exemplo.com', 'segredo');

    expect(r.token, 'abc');
    expect(r.usuario.nome, 'Ana');
    expect(r.usuario.admin, isTrue);
    expect(adaptador.pedidos.single.path, '/auth/login');
    expect(adaptador.pedidos.single.data, {'email': 'ana@exemplo.com', 'senha': 'segredo'});
    expect(adaptador.pedidos.single.headers.containsKey('Authorization'), isFalse);
  });

  test('erro do backend vira ApiErro com código e mensagem', () async {
    final api = criar(
      (_) async => respostaErro(401, 'credenciais_invalidas', 'E-mail ou senha incorretos.'),
    );

    await expectLater(
      api.login('a@b.c', 'x'),
      throwsA(
        isA<ApiErro>()
            .having((e) => e.codigo, 'codigo', 'credenciais_invalidas')
            .having((e) => e.mensagem, 'mensagem', 'E-mail ou senha incorretos.')
            .having((e) => e.status, 'status', 401),
      ),
    );
    // 401 no login é senha errada, não sessão expirada.
    expect(expirou, 0);
  });

  test('falha de rede vira sem_conexao', () async {
    final api = criar(
      (pedido) async => throw DioException.connectionError(
        requestOptions: pedido,
        reason: 'recusada',
      ),
    );

    await expectLater(
      api.marcas(),
      throwsA(isA<ApiErro>().having((e) => e.semConexao, 'semConexao', isTrue)),
    );
  });

  test('envia o token e avisa quando a sessão não vale mais', () async {
    token = 'meu-token';
    final api = criar(
      (_) async => respostaErro(401, 'nao_autenticado', 'Faça login para continuar.'),
    );

    await expectLater(api.marcas(), throwsA(isA<ApiErro>()));

    expect(adaptador.pedidos.single.headers['Authorization'], 'Bearer meu-token');
    expect(expirou, 1);
  });

  test('busca monta a query e interpreta a página', () async {
    final api = criar(
      (_) async => respostaJson(200, {
        'itens': [documentoJson],
        'total': 120,
        'pagina': 2,
        'por_pagina': 50,
      }),
    );

    final p = await api.documentos(q: '  gol 8v ', marcaId: 3, pagina: 2);

    final pedido = adaptador.pedidos.single;
    expect(pedido.path, '/documentos');
    expect(pedido.queryParameters, {'q': 'gol 8v', 'marca_id': 3, 'page': 2});
    expect(p.itens.single.titulo, 'Manual de serviço');
    expect(p.itens.single.ehPdf, isTrue);
    expect(p.itens.single.arquivoModificadoEm, DateTime.utc(2026, 3, 4, 5, 6, 7));
    expect(p.temMais, isTrue);
  });

  test('busca sem texto nem marca não manda filtros vazios', () async {
    final api = criar(
      (_) async => respostaJson(200, {'itens': [], 'total': 0, 'pagina': 1, 'por_pagina': 50}),
    );

    final p = await api.documentos();

    expect(adaptador.pedidos.single.queryParameters, {'page': 1});
    expect(p.temMais, isFalse);
  });

  test('detalhe traz veículos e motores', () async {
    final api = criar(
      (_) async => respostaJson(200, {
        ...documentoJson,
        'arquivo_nome': 'gol.pdf',
        'veiculos': [
          {
            'id': 1,
            'marca_nome': 'VW',
            'modelo_nome': 'Gol',
            'motor_codigo': 'EA111',
            'motor_descricao': '1.6 8v',
            'ano_inicio': 1995,
            'ano_fim': 2005,
          },
          {'id': 2, 'marca_nome': 'Fiat', 'modelo_nome': 'Uno', 'ano_inicio': 2010},
        ],
        'motores': [
          {'id': 9, 'codigo': 'AP', 'descricao': ''},
        ],
      }),
    );

    final d = await api.documento(7);

    expect(d.documento.id, 7);
    expect(d.veiculos[0].rotulo, 'VW Gol · EA111 1.6 8v · 1995–2005');
    expect(d.veiculos[1].rotulo, 'Fiat Uno · desde 2010');
    expect(d.motores.single.rotulo, 'AP');
  });

  test('favoritar usa POST e desfavoritar usa DELETE', () async {
    final api = criar((_) async => ResponseBody.fromString('', 204));

    await api.definirFavorito(7, true);
    await api.definirFavorito(7, false);

    expect(adaptador.pedidos.map((p) => '${p.method} ${p.path}'), [
      'POST /favoritos/7',
      'DELETE /favoritos/7',
    ]);
  });
}
