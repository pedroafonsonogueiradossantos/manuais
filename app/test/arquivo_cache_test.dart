import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/api/api_client.dart';
import 'package:manuais/api/modelos.dart';
import 'package:manuais/arquivos/arquivo_cache.dart';

import 'apoio/adaptador_falso.dart';

void main() {
  late Directory pasta;
  late AdaptadorFalso adaptador;
  final conteudo = '0123456789'.codeUnits;
  final doc = Documento.fromJson(documentoJson);

  ArquivoCache criar(Future<ResponseBody> Function(RequestOptions) responder) {
    adaptador = AdaptadorFalso(responder);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.teste'))
      ..httpClientAdapter = adaptador;
    return ArquivoCache(dio: dio, pasta: () async => pasta);
  }

  File parcial() => File('${pasta.path}/7-md5gol.pdf.part');

  setUp(() async => pasta = await Directory.systemTemp.createTemp('cache_teste'));
  tearDown(() => pasta.delete(recursive: true));

  test('baixa, informa o progresso e reaproveita na segunda vez', () async {
    final cache = criar((_) async => respostaBytes(200, conteudo));
    final progresso = <String>[];

    expect(await cache.existente(doc), isNull);
    final arquivo = await cache.obter(doc, aoProgredir: (r, t) => progresso.add('$r/$t'));

    expect(await arquivo.readAsString(), '0123456789');
    expect(arquivo.path, endsWith('7-md5gol.pdf'));
    expect(progresso.last, '10/10');
    expect(adaptador.pedidos.single.path, '/documentos/7/arquivo');
    expect(adaptador.pedidos.single.headers.containsKey('Range'), isFalse);
    expect(await parcial().exists(), isFalse);

    final denovo = await cache.obter(doc);
    expect(denovo.path, arquivo.path);
    expect(adaptador.pedidos, hasLength(1), reason: 'não deveria baixar de novo');
    expect((await cache.existente(doc))?.path, arquivo.path);
  });

  test('retoma de onde parou com Range e If-Range', () async {
    await parcial().writeAsBytes(conteudo.sublist(0, 4));
    final cache = criar(
      (_) async => respostaBytes(
        206,
        conteudo.sublist(4),
        cabecalhos: {'content-range': 'bytes 4-9/10'},
      ),
    );
    final progresso = <String>[];

    final arquivo = await cache.obter(doc, aoProgredir: (r, t) => progresso.add('$r/$t'));

    expect(await arquivo.readAsString(), '0123456789');
    expect(adaptador.pedidos.single.headers['Range'], 'bytes=4-');
    expect(adaptador.pedidos.single.headers['If-Range'], '"md5gol"');
    expect(progresso.last, '10/10');
  });

  test('se o servidor ignora o Range, recomeça em vez de duplicar', () async {
    await parcial().writeAsBytes('LIXO'.codeUnits);
    final cache = criar((_) async => respostaBytes(200, conteudo));

    final arquivo = await cache.obter(doc);

    expect(await arquivo.readAsString(), '0123456789');
  });

  test('416 descarta o pedaço guardado e baixa do zero', () async {
    await parcial().writeAsBytes(List.filled(50, 0));
    final cache = criar((pedido) async {
      return pedido.headers.containsKey('Range')
          ? respostaErro(416, 'intervalo_invalido', 'Intervalo de bytes inválido.')
          : respostaBytes(200, conteudo);
    });

    final arquivo = await cache.obter(doc);

    expect(await arquivo.readAsString(), '0123456789');
    expect(adaptador.pedidos, hasLength(2));
  });

  test('download com tamanho errado é descartado', () async {
    final cache = criar((_) async => respostaBytes(200, conteudo.sublist(0, 6)));

    await expectLater(
      cache.obter(doc),
      throwsA(isA<ApiErro>().having((e) => e.codigo, 'codigo', 'download_incompleto')),
    );
    expect(await cache.existente(doc), isNull);
    expect(await parcial().exists(), isFalse);
  });

  test('erro do servidor vira ApiErro e não deixa arquivo final', () async {
    final cache = criar(
      (_) async => respostaErro(404, 'arquivo_indisponivel', 'O arquivo não está mais disponível.'),
    );

    await expectLater(
      cache.obter(doc),
      throwsA(isA<ApiErro>().having((e) => e.status, 'status', 404)),
    );
    expect(await cache.existente(doc), isNull);
  });

  test('versão nova do arquivo não reaproveita o download antigo', () async {
    final cache = criar((_) async => respostaBytes(200, conteudo));
    await cache.obter(doc);

    final novo = Documento.fromJson({...documentoJson, 'arquivo_md5': 'md5novo'});
    expect(await cache.existente(novo), isNull);
  });
}
