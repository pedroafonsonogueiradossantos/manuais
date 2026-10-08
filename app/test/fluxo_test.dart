import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/arquivos/visualizador_page.dart';
import 'package:photo_view/photo_view.dart';

import 'apoio/adaptador_falso.dart';
import 'apoio/app_de_teste.dart';

// PNG 1x1 válido.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Backend falso com dois documentos e duas marcas.
class ServidorFalso {
  final pedidos = <String>[];
  final favoritos = <int>{};

  Map<String, dynamic> _doc(int id) => {
    ...documentoJson,
    'id': id,
    'titulo': id == 7 ? 'Manual de serviço' : 'Foto do motor',
    'tipo': id == 7 ? 'manual_servico' : 'foto',
    'mime_type': id == 7 ? 'application/pdf' : 'image/png',
    'tamanho_bytes': id == 7 ? 10 : _png.length,
    'arquivo_md5': 'md5-$id',
    'favorito': favoritos.contains(id),
  };

  Future<ResponseBody> responder(RequestOptions p) async {
    final consulta = p.queryParameters.entries
        .where((e) => e.key != 'page')
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    pedidos.add('${p.method} ${p.path}${consulta.isEmpty ? '' : '?$consulta'}');

    if (p.path == '/auth/login') {
      return (p.data as Map)['senha'] == 'certa'
          ? respostaJson(200, {'token': 'tok', 'usuario': usuarioJson})
          : respostaErro(
              401,
              'credenciais_invalidas',
              'E-mail ou senha incorretos.',
            );
    }
    if (p.headers['Authorization'] != 'Bearer tok') {
      return respostaErro(401, 'nao_autenticado', 'Faça login para continuar.');
    }
    if (p.path == '/marcas') {
      return respostaJson(200, [
        {'id': 1, 'nome': 'Fiat'},
        {'id': 2, 'nome': 'VW'},
      ]);
    }
    if (p.path == '/documentos') {
      final q = '${p.queryParameters['q'] ?? ''}';
      final ids = [
        if (q != 'nada' && p.queryParameters['marca_id'] != 1) 7,
        if (q.isEmpty) 8,
      ];
      return respostaJson(200, {
        'itens': [for (final id in ids) _doc(id)],
        'total': ids.length,
        'pagina': 1,
        'por_pagina': 50,
      });
    }
    if (p.path == '/documentos/8/arquivo') return respostaBytes(200, _png);
    final detalhe = RegExp(r'^/documentos/(\d+)$').firstMatch(p.path);
    if (detalhe != null) {
      return respostaJson(200, {
        ..._doc(int.parse(detalhe[1]!)),
        'arquivo_nome': 'arquivo',
        'veiculos': [
          {
            'id': 1,
            'marca_nome': 'VW',
            'modelo_nome': 'Gol',
            'motor_codigo': 'EA111',
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
    return respostaErro(404, 'nao_encontrado', 'Rota não encontrada.');
  }
}

void main() {
  late ServidorFalso servidor;
  late AmbienteDeTeste amb;

  setUp(() {
    servidor = ServidorFalso();
    amb = AmbienteDeTeste(servidor.responder);
  });

  Future<void> abrirApp(WidgetTester tester) async {
    await amb.abrirApp(tester);
  }

  Future<void> logar(WidgetTester tester, {String senha = 'certa'}) async {
    await tester.enterText(find.byKey(const Key('email')), 'ana@exemplo.com');
    await tester.enterText(find.byKey(const Key('senha')), senha);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  testeApp('senha errada mostra o erro e continua no login', (tester) async {
    await abrirApp(tester);
    await logar(tester, senha: 'errada');

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testeApp('campos vazios não chamam o servidor', (tester) async {
    await abrirApp(tester);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    expect(servidor.pedidos, isEmpty);
  });

  testeApp('login, busca com espera, filtro por marca e sair', (tester) async {
    await abrirApp(tester);
    await logar(tester);

    // Lista inicial com tipo e tamanho.
    expect(find.text('Manual de serviço'), findsOneWidget);
    expect(find.text('Manual de serviço · 10 B'), findsOneWidget);
    expect(find.text('Foto do motor'), findsOneWidget);
    expect(find.text('VW'), findsOneWidget);

    // Digitar só busca depois de o usuário parar.
    servidor.pedidos.clear();
    await tester.enterText(find.byKey(const Key('busca')), 'go');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const Key('busca')), 'gol');
    await tester.pump(const Duration(milliseconds: 200));
    expect(servidor.pedidos, isEmpty);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(servidor.pedidos, ['GET /documentos?q=gol']);
    expect(find.text('Foto do motor'), findsNothing);

    // Sem resultado.
    await tester.enterText(find.byKey(const Key('busca')), 'nada');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Nenhum documento encontrado.'), findsOneWidget);

    // Limpar e filtrar por marca.
    await tester.tap(find.byTooltip('Limpar'));
    await tester.pumpAndSettle();
    servidor.pedidos.clear();
    await tester.tap(find.text('Fiat'));
    await tester.pumpAndSettle();
    expect(servidor.pedidos, ['GET /documentos?marca_id=1']);
    expect(find.text('Manual de serviço'), findsNothing);
    expect(find.text('Foto do motor'), findsOneWidget);

    // Sair volta ao login e apaga o token.
    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(amb.cofre.dados, isEmpty);
  });

  testeApp('detalhe mostra veículos e favorita', (tester) async {
    await abrirApp(tester);
    await logar(tester);

    await tester.tap(find.text('Manual de serviço'));
    await tester.pumpAndSettle();

    expect(find.text('VW Gol · EA111'), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);

    await tester.tap(find.byTooltip('Favoritar'));
    await tester.pumpAndSettle();
    expect(servidor.favoritos, {7});
    expect(find.byTooltip('Remover dos favoritos'), findsOneWidget);

    // A estrela aparece na lista ao voltar, sem recarregar.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testeApp('abrir baixa o arquivo e mostra o visualizador', (tester) async {
    await abrirApp(tester);
    await logar(tester);
    await tester.tap(find.text('Foto do motor'));
    await tester.pumpAndSettle();

    await amb.comDisco(
      tester,
      () => tester.tap(find.byKey(const Key('abrir'))),
      ate: () => AmbienteDeTeste.arquivosEm(amb.cache).isNotEmpty,
    );

    expect(find.byType(VisualizadorPage), findsOneWidget);
    expect(find.byType(PhotoView), findsOneWidget);
    final baixado = amb.cache.listSync().single as File;
    expect(baixado.path, endsWith('8-md5-8.png'));
    expect(baixado.readAsBytesSync(), _png);
  });

  testeApp(
    'sessão guardada abre direto na busca; token inválido volta ao login',
    (tester) async {
      amb.cofre.dados['token'] = 'tok';
      amb.cofre.dados['usuario'] = jsonEncode(usuarioJson);
      await abrirApp(tester);
      expect(find.text('Manual de serviço'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      amb.cofre.dados['token'] = 'vencido';
      await abrirApp(tester);
      expect(find.text('Entrar'), findsOneWidget);
      expect(amb.cofre.dados, isEmpty);
    },
  );
}
