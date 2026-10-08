import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/api/api_client.dart';
import 'package:manuais/api/modelos.dart';
import 'package:manuais/arquivos/arquivo_cache.dart';
import 'package:manuais/offline/banco_local.dart';
import 'package:manuais/offline/offline.dart';

import 'apoio/adaptador_falso.dart';

void main() {
  late Directory pasta;
  late BancoLocal banco;
  late AdaptadorFalso adaptador;
  late Offline offline;
  var wifi = true;
  var semRede = false;

  /// Favoritos e versão do arquivo de cada documento no "servidor".
  late Set<int> favoritosNoServidor;
  late Map<int, String> md5NoServidor;

  Map<String, dynamic> docJson(int id) => {
    ...documentoJson,
    'id': id,
    'titulo': 'Documento $id',
    'arquivo_md5': md5NoServidor[id] ?? 'v1',
    'favorito': favoritosNoServidor.contains(id),
  };

  Future<DocumentoDetalhe> detalhe(int id) => offline.api.documento(id);

  Future<ResponseBody> responder(RequestOptions pedido) async {
    if (semRede) {
      throw DioException.connectionError(
        requestOptions: pedido,
        reason: 'sem rede',
      );
    }
    final caminho = pedido.path;
    if (caminho == '/favoritos') {
      // Duas páginas de 1 item para exercitar a paginação.
      final ids = favoritosNoServidor.toList()..sort();
      final pagina = pedido.queryParameters['page'] as int;
      return respostaJson(200, {
        'itens': [if (pagina <= ids.length) docJson(ids[pagina - 1])],
        'total': ids.length,
        'pagina': pagina,
        'por_pagina': 1,
      });
    }
    final arquivo = RegExp(r'^/documentos/(\d+)/arquivo$').firstMatch(caminho);
    if (arquivo != null) return respostaBytes(200, '0123456789'.codeUnits);
    final doc = RegExp(r'^/documentos/(\d+)$').firstMatch(caminho);
    if (doc != null) {
      return respostaJson(200, {
        ...docJson(int.parse(doc[1]!)),
        'veiculos': [],
        'motores': [],
      });
    }
    final favorito = RegExp(r'^/favoritos/(\d+)$').firstMatch(caminho);
    if (favorito != null) {
      final id = int.parse(favorito[1]!);
      pedido.method == 'POST'
          ? favoritosNoServidor.add(id)
          : favoritosNoServidor.remove(id);
      return ResponseBody.fromString('', 204);
    }
    return respostaErro(404, 'nao_encontrado', 'Rota não encontrada.');
  }

  List<String> arquivosNaPasta() => pasta.existsSync()
      ? (pasta.listSync().map((f) => f.uri.pathSegments.last).toList()..sort())
      : [];

  int downloads() =>
      adaptador.pedidos.where((p) => p.path.endsWith('/arquivo')).length;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('offline_teste');
    banco = BancoLocal(NativeDatabase.memory());
    wifi = true;
    semRede = false;
    favoritosNoServidor = {};
    md5NoServidor = {};
    adaptador = AdaptadorFalso(responder);
    final api = ApiClient(
      baseUrl: 'http://api.teste',
      token: () => 'tok',
      adaptador: adaptador,
    );
    offline = Offline(
      api: api,
      banco: banco,
      salvos: ArquivoCache(dio: api.dio, pasta: () async => pasta),
      noWifi: () async => wifi,
    );
  });

  tearDown(() async {
    await banco.close();
    if (pasta.existsSync()) await pasta.delete(recursive: true);
  });

  test('salvar baixa o arquivo e registra; remover apaga os dois', () async {
    final arquivo = await offline.salvar(await detalhe(7));

    expect(await arquivo.readAsString(), '0123456789');
    expect((await banco.buscar(7))!.arquivoLocal, '7-v1.pdf');
    expect((await offline.arquivoSalvo(7))!.path, arquivo.path);

    await offline.remover(7);

    expect(await banco.buscar(7), isNull);
    expect(await offline.arquivoSalvo(7), isNull);
    expect(arquivosNaPasta(), isEmpty);
  });

  test(
    'salvar de novo depois de o arquivo mudar troca a versão e apaga a antiga',
    () async {
      await offline.salvar(await detalhe(7));
      md5NoServidor[7] = 'v2';

      await offline.salvar(await detalhe(7));

      expect(arquivosNaPasta(), ['7-v2.pdf']);
      expect((await banco.buscar(7))!.versaoBaixada, 'v2');
    },
  );

  test('arquivo apagado por fora não é dado como salvo', () async {
    final arquivo = await offline.salvar(await detalhe(7));
    await arquivo.delete();

    expect(await offline.arquivoSalvo(7), isNull);
  });

  test('favoritar grava no servidor e na cópia local', () async {
    final doc = (await detalhe(7)).documento;

    await offline.definirFavorito(doc, true);
    expect(favoritosNoServidor, {7});
    expect((await banco.observarFavoritos().first).single.id, 7);

    await offline.definirFavorito(doc, false);
    expect(favoritosNoServidor, isEmpty);
    expect(await banco.observarFavoritos().first, isEmpty);
  });

  test('sem conexão, favoritar falha e a cópia local não muda', () async {
    final doc = (await detalhe(7)).documento;
    semRede = true;

    await expectLater(
      offline.definirFavorito(doc, true),
      throwsA(isA<ApiErro>().having((e) => e.semConexao, 'semConexao', isTrue)),
    );
    expect(await banco.observarFavoritos().first, isEmpty);
  });

  test(
    'sincronizarFavoritos percorre todas as páginas e espelha o servidor',
    () async {
      await banco.definirFavorito((await detalhe(9)).documento, true);
      favoritosNoServidor = {3, 5};

      await offline.sincronizarFavoritos();

      expect((await banco.observarFavoritos().first).map((d) => d.id), [3, 5]);
      expect(
        downloads(),
        0,
        reason: 'download automático está desligado por padrão',
      );
    },
  );

  test(
    'com a opção ligada e no Wi-Fi, baixa os favoritos que faltam',
    () async {
      favoritosNoServidor = {3, 5};
      await offline.definirAutoBaixar(true);
      await offline.salvar(await detalhe(3));
      final antes = downloads();

      await offline.sincronizarFavoritos();

      expect(downloads() - antes, 1, reason: 'o 3 já estava no aparelho');
      expect(arquivosNaPasta(), ['3-v1.pdf', '5-v1.pdf']);
      expect((await banco.buscar(5))!.favorito, isTrue);
    },
  );

  test('fora do Wi-Fi não baixa sozinho', () async {
    favoritosNoServidor = {3};
    await offline.definirAutoBaixar(true);
    wifi = false;

    await offline.sincronizarFavoritos();

    expect(downloads(), 0);
    expect((await banco.buscar(3))!.baixado, isFalse);
  });

  test(
    'ligar a opção já baixa os favoritos; favoritar depois também',
    () async {
      favoritosNoServidor = {3};
      await offline.sincronizarFavoritos();
      expect(downloads(), 0);

      await offline.definirAutoBaixar(true);
      expect(arquivosNaPasta(), ['3-v1.pdf']);

      await offline.definirFavorito((await detalhe(4)).documento, true);
      expect(arquivosNaPasta(), ['3-v1.pdf', '4-v1.pdf']);
    },
  );

  test('outro usuário no aparelho começa sem os dados do anterior', () async {
    const ana = Usuario(id: 1, nome: 'Ana', email: 'a@x.com', papel: 'admin');
    const beto = Usuario(
      id: 2,
      nome: 'Beto',
      email: 'b@x.com',
      papel: 'mecanico',
    );

    await offline.prepararPara(ana);
    await offline.salvar(await detalhe(7));
    await offline.definirAutoBaixar(true);

    // A mesma pessoa entrando de novo mantém tudo.
    await offline.prepararPara(ana);
    expect(await offline.arquivoSalvo(7), isNotNull);

    await offline.prepararPara(beto);
    expect(await banco.buscar(7), isNull);
    expect(arquivosNaPasta(), isEmpty);
    expect(await offline.autoBaixar(), isFalse);
  });
}
