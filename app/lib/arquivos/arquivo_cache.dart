import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';
import '../api/modelos.dart';

typedef Progresso = void Function(int recebido, int total);

/// Baixa os arquivos dos documentos para o disco. O visualizador sempre abre
/// um arquivo local: nada fica inteiro na memória e o download pode ser
/// retomado de onde parou.
class ArquivoCache {
  ArquivoCache({required this.dio, required this.pasta});

  final Dio dio;
  final Future<Directory> Function() pasta;

  /// O nome inclui a versão do arquivo: se o arquivo mudar no servidor, o
  /// antigo deixa de ser encontrado e é baixado de novo.
  Future<File> _destino(Documento doc) async {
    final ext = switch (doc.mimeType) {
      'application/pdf' => '.pdf',
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '',
    };
    return File(p.join((await pasta()).path, '${doc.id}-${doc.versaoDoArquivo}$ext'));
  }

  /// Arquivo já baixado nesta versão, ou null.
  Future<File?> existente(Documento doc) async {
    final arquivo = await _destino(doc);
    return await arquivo.exists() ? arquivo : null;
  }

  /// Devolve o arquivo local, baixando se for preciso. Lança [ApiErro].
  Future<File> obter(
    Documento doc, {
    Progresso? aoProgredir,
    CancelToken? cancelamento,
  }) async {
    final destino = await _destino(doc);
    if (await destino.exists()) return destino;
    await destino.parent.create(recursive: true);

    final parcial = File('${destino.path}.part');
    try {
      await _baixar(doc, parcial, aoProgredir, cancelamento);
    } on DioException catch (e) {
      // 416: o pedaço guardado não bate com o arquivo. Recomeça do zero.
      if (e.response?.statusCode != 416) throw ApiClient.traduzir(e);
      await _apagar(parcial);
      try {
        await _baixar(doc, parcial, aoProgredir, cancelamento);
      } on DioException catch (e) {
        throw ApiClient.traduzir(e);
      }
    }

    final tamanho = await parcial.length();
    if (doc.tamanhoBytes > 0 && tamanho != doc.tamanhoBytes) {
      await _apagar(parcial);
      throw const ApiErro(
        codigo: 'download_incompleto',
        mensagem: 'O download veio incompleto. Tente de novo.',
      );
    }
    return parcial.rename(destino.path);
  }

  Future<void> _baixar(
    Documento doc,
    File parcial,
    Progresso? aoProgredir,
    CancelToken? cancelamento,
  ) async {
    // Só retoma com md5: o If-Range garante que o resto é do mesmo arquivo.
    var inicio = 0;
    if (await parcial.exists()) {
      if (doc.arquivoMd5 != null) {
        inicio = await parcial.length();
      } else {
        await parcial.delete();
      }
    }

    final resposta = await dio.get<ResponseBody>(
      '/documentos/${doc.id}/arquivo',
      cancelToken: cancelamento,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          if (inicio > 0) 'Range': 'bytes=$inicio-',
          if (inicio > 0) 'If-Range': '"${doc.arquivoMd5}"',
        },
      ),
    );

    // 200 em vez de 206 = o servidor mandou o arquivo inteiro.
    final retomando = resposta.statusCode == 206;
    if (!retomando) inicio = 0;

    final tamanhoDoCorpo =
        int.tryParse(resposta.headers.value(Headers.contentLengthHeader) ?? '') ?? 0;
    final total = tamanhoDoCorpo > 0 ? inicio + tamanhoDoCorpo : doc.tamanhoBytes;

    final saida = parcial.openWrite(
      mode: retomando ? FileMode.append : FileMode.write,
    );
    var recebido = inicio;
    try {
      await for (final pedaco in resposta.data!.stream) {
        saida.add(pedaco);
        recebido += pedaco.length;
        aoProgredir?.call(recebido, total);
      }
    } finally {
      // Fecha mesmo se a rede cair: o que já chegou fica para retomar depois.
      await saida.close();
    }
  }

  Future<void> _apagar(File arquivo) async {
    if (await arquivo.exists()) await arquivo.delete();
  }
}
