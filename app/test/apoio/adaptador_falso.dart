import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptador HTTP de teste: responde pelo callback e guarda os pedidos.
class AdaptadorFalso implements HttpClientAdapter {
  AdaptadorFalso(this.responder);

  Future<ResponseBody> Function(RequestOptions pedido) responder;
  final pedidos = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    pedidos.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody respostaJson(int status, Object? corpo) => ResponseBody.fromString(
  jsonEncode(corpo),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody respostaErro(int status, String codigo, String mensagem) =>
    respostaJson(status, {
      'erro': {'codigo': codigo, 'mensagem': mensagem},
    });

ResponseBody respostaBytes(
  int status,
  List<int> bytes, {
  Map<String, String> cabecalhos = const {},
}) => ResponseBody.fromBytes(
  bytes,
  status,
  headers: {
    Headers.contentLengthHeader: ['${bytes.length}'],
    for (final e in cabecalhos.entries) e.key: [e.value],
  },
);

const documentoJson = {
  'id': 7,
  'titulo': 'Manual de serviço',
  'tipo': 'manual_servico',
  'mime_type': 'application/pdf',
  'tamanho_bytes': 10,
  'arquivo_md5': 'md5gol',
  'arquivo_modificado_em': '2026-03-04T05:06:07Z',
  'indisponivel': false,
  'favorito': false,
};

const usuarioJson = {
  'id': 1,
  'nome': 'Ana',
  'email': 'ana@exemplo.com',
  'papel': 'admin',
};
