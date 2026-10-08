import 'dart:convert';

import 'package:dio/dio.dart';

import 'adaptador_falso.dart';

/// PNG 1x1 válido.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Backend falso com estado: dois documentos de imagem (7 do Gol, 8 do Uno),
/// favoritos, cadastros e senha. Dá para "derrubar a rede" com [semRede].
class ServidorFalso {
  bool semRede = false;
  String senha = 'senha-antiga';
  String token = 'tok';
  final pedidos = <String>[];
  final corpos = <String, Object?>{};
  final favoritos = <int>{};
  final md5 = <int, String>{7: 'v1', 8: 'v1'};
  final titulos = <int, String>{7: 'Manual do Gol', 8: 'Esquema do Uno'};
  final marcas = <int, String>{1: 'Fiat', 2: 'VW'};
  final marcasEmUso = <int>{2};

  Map<String, dynamic> doc(int id) => {
    'id': id,
    'titulo': titulos[id],
    'tipo': id == 7 ? 'manual_servico' : 'diagrama_eletrico',
    'mime_type': 'image/png',
    'tamanho_bytes': png.length,
    'arquivo_md5': md5[id],
    'arquivo_modificado_em': '2026-03-04T05:06:07Z',
    'indisponivel': false,
    'favorito': favoritos.contains(id),
  };

  Map<String, dynamic> _pagina(Iterable<int> ids) => {
    'itens': [for (final id in ids) doc(id)],
    'total': ids.length,
    'pagina': 1,
    'por_pagina': 50,
  };

  Future<ResponseBody> responder(RequestOptions p) async {
    if (semRede) {
      throw DioException.connectionError(requestOptions: p, reason: 'sem rede');
    }
    final consulta = p.queryParameters.entries
        .where((e) => e.key != 'page')
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    final rota = '${p.method} ${p.path}';
    pedidos.add('$rota${consulta.isEmpty ? '' : '?$consulta'}');
    if (p.data != null) corpos[rota] = p.data;

    if (p.headers['Authorization'] != 'Bearer $token') {
      return respostaErro(401, 'nao_autenticado', 'Faça login para continuar.');
    }
    final dados = p.data is Map ? p.data as Map : const {};

    switch (rota) {
      case 'GET /marcas':
        return respostaJson(200, [
          for (final m in marcas.entries) {'id': m.key, 'nome': m.value},
        ]);
      case 'GET /modelos':
        return respostaJson(200, [
          {'id': 10, 'marca_id': p.queryParameters['marca_id'], 'nome': 'Gol'},
        ]);
      case 'GET /motores':
        return respostaJson(200, [
          {'id': 20, 'codigo': 'EA111', 'descricao': '1.6 8v'},
        ]);
      case 'GET /documentos':
        final q = p.queryParameters;
        return respostaJson(
          200,
          _pagina(
            titulos.keys.where((id) {
              if (q['tipo'] != null && doc(id)['tipo'] != q['tipo']) {
                return false;
              }
              if ((q['modelo_id'] ?? q['motor_id']) != null && id != 7) {
                return false;
              }
              if (q['marca_id'] == 1 && id != 8) return false;
              return true;
            }),
          ),
        );
      case 'GET /favoritos':
        return respostaJson(200, _pagina(favoritos.toList()..sort()));
      case 'PUT /me/senha':
        if (dados['senha_atual'] != senha) {
          return respostaErro(
            422,
            'senha_atual_incorreta',
            'A senha atual está incorreta.',
          );
        }
        senha = dados['senha_nova'] as String;
        token = 'tok-novo';
        return respostaJson(200, {'token': token});
    }

    final arquivo = RegExp(r'^/documentos/(\d+)/arquivo$').firstMatch(p.path);
    if (arquivo != null) return respostaBytes(200, png);

    final documento = RegExp(r'^/(admin/)?documentos/(\d+)$')
        .firstMatch(p.path);
    if (documento != null) {
      final id = int.parse(documento[2]!);
      if (!titulos.containsKey(id)) {
        return respostaErro(404, 'nao_encontrado', 'Registro não encontrado.');
      }
      switch (p.method) {
        case 'PUT':
          titulos[id] = dados['titulo'] as String;
          return respostaJson(200, {'id': id});
        case 'DELETE':
          titulos.remove(id);
          favoritos.remove(id);
          return ResponseBody.fromString('', 204);
      }
      return respostaJson(200, {
        ...doc(id),
        'veiculos': [
          {
            'id': id,
            'marca_nome': id == 7 ? 'VW' : 'Fiat',
            'modelo_nome': id == 7 ? 'Gol' : 'Uno',
          },
        ],
        'motores': [],
      });
    }

    final favorito = RegExp(r'^/favoritos/(\d+)$').firstMatch(p.path);
    if (favorito != null) {
      final id = int.parse(favorito[1]!);
      p.method == 'POST' ? favoritos.add(id) : favoritos.remove(id);
      return ResponseBody.fromString('', 204);
    }

    final marca = RegExp(r'^/admin/marcas/(\d+)$').firstMatch(p.path);
    if (marca != null) {
      final id = int.parse(marca[1]!);
      if (p.method == 'PUT') {
        marcas[id] = dados['nome'] as String;
        return respostaJson(200, {'id': id, 'nome': marcas[id]});
      }
      if (marcasEmUso.contains(id)) {
        return respostaErro(
          409,
          'em_uso',
          'O registro está em uso e não pode ser excluído.',
        );
      }
      marcas.remove(id);
      return ResponseBody.fromString('', 204);
    }
    return respostaErro(404, 'nao_encontrado', 'Rota não encontrada: $rota');
  }
}
