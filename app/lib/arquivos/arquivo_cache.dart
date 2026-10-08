import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';
import '../api/modelos.dart';

typedef Progresso = void Function(int recebido, int total);

/// O que o cache precisa saber de um arquivo no servidor.
class ArquivoRemoto {
  const ArquivoRemoto({
    required this.url,
    required this.chave,
    required this.mimeType,
    required this.tamanhoBytes,
    this.md5,
  });

  factory ArquivoRemoto.doDocumento(Documento doc) => ArquivoRemoto(
    url: '/documentos/${doc.id}/arquivo',
    chave: '${doc.id}-${doc.versaoDoArquivo}',
    mimeType: doc.mimeType,
    tamanhoBytes: doc.tamanhoBytes,
    md5: doc.arquivoMd5,
  );

  /// Arquivo ainda não catalogado, visto pelo admin antes de catalogar.
  factory ArquivoRemoto.doPendente(ArquivoPendente a) => ArquivoRemoto(
    url: ApiClient.caminhoDoPreview(a.storageFileId),
    chave:
        'preview-${a.storageFileId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}',
    mimeType: a.mimeType,
    tamanhoBytes: a.tamanhoBytes,
  );

  final String url;

  /// Nome do arquivo local; muda quando o conteúdo muda.
  final String chave;
  final String mimeType;
  final int tamanhoBytes;
  final String? md5;
}

/// Baixa os arquivos dos documentos para o disco. O visualizador sempre abre
/// um arquivo local: nada fica inteiro na memória e o download pode ser
/// retomado de onde parou.
class ArquivoCache {
  ArquivoCache({required this.dio, required this.pasta});

  final Dio dio;
  final Future<Directory> Function() pasta;

  /// O nome inclui a versão do arquivo: se o arquivo mudar no servidor, o
  /// antigo deixa de ser encontrado e é baixado de novo.
  Future<File> _destino(ArquivoRemoto doc) async {
    final ext = switch (doc.mimeType) {
      'application/pdf' => '.pdf',
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '',
    };
    return File(p.join((await pasta()).path, '${doc.chave}$ext'));
  }

  /// Arquivo já baixado nesta versão, ou null.
  Future<File?> existente(Documento doc) async {
    final arquivo = await _destino(ArquivoRemoto.doDocumento(doc));
    return await arquivo.exists() ? arquivo : null;
  }

  /// Devolve o arquivo local do documento, baixando se for preciso.
  /// Lança [ApiErro].
  Future<File> obter(
    Documento doc, {
    Progresso? aoProgredir,
    CancelToken? cancelamento,
  }) => obterRemoto(
    ArquivoRemoto.doDocumento(doc),
    aoProgredir: aoProgredir,
    cancelamento: cancelamento,
  );

  Future<File> obterRemoto(
    ArquivoRemoto doc, {
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
    ArquivoRemoto doc,
    File parcial,
    Progresso? aoProgredir,
    CancelToken? cancelamento,
  ) async {
    // Só retoma com md5: o If-Range garante que o resto é do mesmo arquivo.
    var inicio = 0;
    if (await parcial.exists()) {
      if (doc.md5 != null) {
        inicio = await parcial.length();
      } else {
        await parcial.delete();
      }
    }

    final resposta = await dio.get<ResponseBody>(
      doc.url,
      cancelToken: cancelamento,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          if (inicio > 0) 'Range': 'bytes=$inicio-',
          if (inicio > 0) 'If-Range': '"${doc.md5}"',
        },
      ),
    );

    // 200 em vez de 206 = o servidor mandou o arquivo inteiro.
    final retomando = resposta.statusCode == 206;
    if (!retomando) inicio = 0;

    final tamanhoDoCorpo =
        int.tryParse(
          resposta.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        0;
    final total = tamanhoDoCorpo > 0
        ? inicio + tamanhoDoCorpo
        : doc.tamanhoBytes;

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
