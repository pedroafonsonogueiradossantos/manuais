import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/adaptador_falso.dart';
import 'apoio/app_de_teste.dart';

/// Backend falso com estado, o bastante para catalogar um arquivo do zero.
class ServidorAdmin {
  final marcas = <Map<String, dynamic>>[
    {'id': 1, 'nome': 'Fiat'},
  ];
  final modelos = <Map<String, dynamic>>[];
  final motores = <Map<String, dynamic>>[];
  final veiculos = <Map<String, dynamic>>[];
  final documentos = <Map<String, dynamic>>[];
  final ignorados = <String>{};
  final usuarios = <Map<String, dynamic>>[
    {...usuarioJson, 'ativo': true},
  ];
  final pendentes = <Map<String, dynamic>>[
    {
      'storage_file_id': 'f1',
      'nome': 'gol_1.6_servico.pdf',
      'caminho': 'VW/Gol',
      'mime_type': 'application/pdf',
      'tamanho_bytes': 2048,
    },
    {
      'storage_file_id': 'f2',
      'nome': 'motor.jpg',
      'caminho': 'VW/Gol',
      'mime_type': 'image/jpeg',
      'tamanho_bytes': 100,
    },
  ];
  var sincronizacoes = 0;
  var _id = 100;

  Map<String, dynamic> _novo(List<Map<String, dynamic>> lista, Map dados) {
    final item = {'id': ++_id, ...dados.cast<String, dynamic>()};
    lista.add(item);
    return item;
  }

  Future<ResponseBody> responder(RequestOptions p) async {
    final rota = '${p.method} ${p.path}';
    final dados = p.data is Map ? p.data as Map : const {};
    switch (rota) {
      case 'GET /marcas':
        return respostaJson(200, marcas);
      case 'POST /admin/marcas':
        return respostaJson(201, _novo(marcas, dados));
      case 'GET /modelos':
        return respostaJson(200, [
          for (final m in modelos)
            if (m['marca_id'] == p.queryParameters['marca_id']) m,
        ]);
      case 'POST /admin/modelos':
        return respostaJson(201, _novo(modelos, dados));
      case 'GET /motores':
        return respostaJson(200, motores);
      case 'POST /admin/motores':
        return respostaJson(201, _novo(motores, dados));
      case 'POST /admin/veiculos':
        return respostaJson(201, {'id': _novo(veiculos, dados)['id']});
      case 'POST /admin/documentos':
        final doc = _novo(documentos, dados);
        pendentes.removeWhere(
          (a) => a['storage_file_id'] == dados['storage_file_id'],
        );
        return respostaJson(201, {'id': doc['id']});
      case 'GET /documentos':
        return respostaJson(200, {
          'itens': [
            for (final d in documentos)
              {
                ...documentoJson,
                'id': d['id'],
                'titulo': d['titulo'],
                'tipo': d['tipo'],
              },
          ],
          'total': documentos.length,
          'pagina': 1,
          'por_pagina': 50,
        });
      case 'GET /admin/drive/pendentes':
        final querIgnorados = p.queryParameters['ignorados'] == 'true';
        final itens = [
          for (final a in pendentes)
            if (ignorados.contains(a['storage_file_id']) == querIgnorados)
              {...a, 'ignorado': querIgnorados},
        ];
        return respostaJson(200, {
          'itens': itens,
          'total': itens.length,
          'pagina': 1,
          'por_pagina': 50,
        });
      case 'POST /admin/drive/sincronizar':
        sincronizacoes++;
        return respostaJson(200, {
          'arquivos': pendentes.length,
          'removidos': 0,
        });
      case 'GET /admin/usuarios':
        return respostaJson(200, usuarios);
      case 'POST /admin/usuarios':
        if (usuarios.any((u) => u['email'] == dados['email'])) {
          return respostaErro(
            409,
            'conflito',
            'Já existe um usuário com este e-mail.',
          );
        }
        return respostaJson(
          201,
          _novo(usuarios, {...dados, 'ativo': true}..remove('senha')),
        );
    }
    final ignorar = RegExp(r'^/admin/drive/arquivos/(.+)/ignorar$')
        .firstMatch(p.path);
    if (ignorar != null) {
      p.method == 'POST'
          ? ignorados.add(ignorar[1]!)
          : ignorados.remove(ignorar[1]!);
      return ResponseBody.fromString('', 204);
    }
    final usuario = RegExp(r'^/admin/usuarios/(\d+)$').firstMatch(p.path);
    if (usuario != null && p.method == 'PUT') {
      final u = usuarios.firstWhere((u) => u['id'] == int.parse(usuario[1]!));
      u.addAll({...dados.cast<String, dynamic>()}..remove('senha'));
      return respostaJson(200, u);
    }
    return respostaErro(404, 'nao_encontrado', 'Rota não encontrada: $rota');
  }
}

void main() {
  late ServidorAdmin servidor;

  Future<void> abrirApp(WidgetTester tester, {String papel = 'admin'}) async {
    servidor = ServidorAdmin();
    final amb = AmbienteDeTeste(servidor.responder);
    amb.cofre.dados['token'] = 'tok';
    amb.cofre.dados['usuario'] = jsonEncode({...usuarioJson, 'papel': papel});
    await amb.abrirApp(tester);
  }

  Future<void> abrirAdmin(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administração'));
    await tester.pumpAndSettle();
  }

  /// Digita no seletor aberto e toca em "Criar".
  Future<void> criarNoSeletor(WidgetTester tester, String texto) async {
    await tester.enterText(find.byKey(const Key('filtro-seletor')), texto);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar "$texto"'));
    await tester.pumpAndSettle();
  }

  testeApp('mecânico não vê a administração', (tester) async {
    await abrirApp(tester, papel: 'mecanico');
    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();

    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Administração'), findsNothing);
  });

  testeApp('cataloga um arquivo criando marca, modelo e motor na hora', (
    tester,
  ) async {
    await abrirApp(tester);
    await abrirAdmin(tester);

    expect(find.text('2 a catalogar'), findsOneWidget);
    expect(find.text('VW/Gol · 2,0 KB'), findsOneWidget);

    await tester.tap(find.text('gol_1.6_servico.pdf'));
    await tester.pumpAndSettle();

    // Título sugerido a partir do nome do arquivo; tipo pelo formato.
    expect(find.widgetWithText(TextField, 'gol 1.6 servico'), findsOneWidget);
    expect(find.text('Manual de serviço'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('titulo')),
      'Manual de serviço Gol',
    );

    // Veículo: marca nova, modelo novo, motor novo, anos.
    await tester.tap(find.text('Adicionar veículo'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Adicionar'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('campo-marca')));
    await tester.pumpAndSettle();
    expect(find.text('Fiat'), findsOneWidget);
    await criarNoSeletor(tester, 'VW');

    await tester.tap(find.byKey(const Key('campo-modelo')));
    await tester.pumpAndSettle();
    await criarNoSeletor(tester, 'Gol');

    await tester.tap(find.byKey(const Key('campo-motor')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('filtro-seletor')), 'EA111');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar "EA111"'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('motor-descricao')), '1.6 8v');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ano-inicio')), '1995');
    await tester.enterText(find.byKey(const Key('ano-fim')), '2005');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('VW Gol · EA111 1.6 8v · 1995–2005'), findsOneWidget);

    await tester.tap(find.byKey(const Key('salvar')));
    await tester.pumpAndSettle();

    // O que chegou ao servidor.
    final marcaVw = servidor.marcas.last;
    expect(marcaVw['nome'], 'VW');
    expect(servidor.modelos.single, containsPair('marca_id', marcaVw['id']));
    expect(servidor.motores.single, {
      'id': isA<int>(),
      'codigo': 'EA111',
      'descricao': '1.6 8v',
    });
    final veiculo = servidor.veiculos.single;
    expect(veiculo, {
      'id': isA<int>(),
      'modelo_id': servidor.modelos.single['id'],
      'motor_id': servidor.motores.single['id'],
      'ano_inicio': 1995,
      'ano_fim': 2005,
    });
    expect(servidor.documentos.single, {
      'id': isA<int>(),
      'titulo': 'Manual de serviço Gol',
      'tipo': 'manual_servico',
      'storage_file_id': 'f1',
      'veiculo_ids': [veiculo['id']],
      'motor_ids': <int>[],
    });

    // Voltou para a fila, sem o arquivo catalogado.
    expect(find.text('1 a catalogar'), findsOneWidget);
    expect(find.text('gol_1.6_servico.pdf'), findsNothing);

    // O próximo arquivo reaproveita os veículos do anterior.
    await tester.tap(find.text('motor.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('Foto'), findsOneWidget);
    await tester.tap(find.text('Usar os do último documento'));
    await tester.pumpAndSettle();
    expect(find.text('VW Gol · EA111 1.6 8v · 1995–2005'), findsOneWidget);
    await tester.tap(find.byKey(const Key('salvar')));
    await tester.pumpAndSettle();
    expect(servidor.documentos.last['veiculo_ids'], [veiculo['id']]);
    expect(servidor.documentos.last['tipo'], 'foto');
    expect(find.text('0 a catalogar'), findsOneWidget);

    // De volta à busca, os documentos novos aparecem e a marca nova vira filtro.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Manual de serviço Gol'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'VW'), findsOneWidget);
  });

  testeApp('título vazio não salva', (tester) async {
    await abrirApp(tester);
    await abrirAdmin(tester);
    await tester.tap(find.text('motor.jpg'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('titulo')), '  ');
    await tester.tap(find.byKey(const Key('salvar')));
    await tester.pumpAndSettle();

    expect(find.text('Informe o título.'), findsOneWidget);
    expect(servidor.documentos, isEmpty);
  });

  testeApp(
    'ignorar tira da fila e dá para devolver; sincronizar relê o Drive',
    (tester) async {
      await abrirApp(tester);
      await abrirAdmin(tester);

      await tester.tap(find.text('motor.jpg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignorar'));
      await tester.pumpAndSettle();
      expect(servidor.ignorados, {'f2'});
      expect(find.text('1 a catalogar'), findsOneWidget);
      expect(find.text('motor.jpg'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Ignorados'));
      await tester.pumpAndSettle();
      expect(find.text('1 ignorados'), findsOneWidget);
      await tester.tap(find.text('motor.jpg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devolver à fila'));
      await tester.pumpAndSettle();
      expect(servidor.ignorados, isEmpty);
      expect(find.text('0 ignorados'), findsOneWidget);

      await tester.tap(find.byTooltip('Sincronizar com o Drive'));
      await tester.pumpAndSettle();
      expect(servidor.sincronizacoes, 1);
      expect(
        find.text('Drive sincronizado: 2 arquivos, 0 removidos.'),
        findsOneWidget,
      );
    },
  );

  testeApp('cria e edita usuário', (tester) async {
    await abrirApp(tester);
    await abrirAdmin(tester);
    await tester.tap(find.text('Usuários'));
    await tester.pumpAndSettle();
    expect(find.text('ana@exemplo.com · admin'), findsOneWidget);

    await tester.tap(find.text('Novo usuário'));
    await tester.pumpAndSettle();

    // Senha curta é barrada antes de ir ao servidor.
    await tester.enterText(find.byKey(const Key('usuario-nome')), 'Beto');
    await tester.enterText(
      find.byKey(const Key('usuario-email')),
      'beto@exemplo.com',
    );
    await tester.enterText(find.byKey(const Key('usuario-senha')), 'curta');
    await tester.tap(find.byKey(const Key('usuario-salvar')));
    await tester.pumpAndSettle();
    expect(find.text('Mínimo de 8 caracteres.'), findsOneWidget);
    expect(servidor.usuarios, hasLength(1));

    await tester.enterText(
      find.byKey(const Key('usuario-senha')),
      'senha-do-beto',
    );
    await tester.tap(find.byKey(const Key('usuario-salvar')));
    await tester.pumpAndSettle();
    expect(servidor.usuarios.last, containsPair('papel', 'mecanico'));
    expect(find.text('beto@exemplo.com · mecânico'), findsOneWidget);

    // Desativar.
    await tester.tap(find.text('Beto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('usuario-salvar')));
    await tester.pumpAndSettle();
    expect(servidor.usuarios.last['ativo'], isFalse);
    expect(
      find.text('beto@exemplo.com · mecânico · desativado'),
      findsOneWidget,
    );
  });

  testeApp('erro do servidor ao salvar usuário aparece na tela', (
    tester,
  ) async {
    await abrirApp(tester);
    await abrirAdmin(tester);
    await tester.tap(find.text('Usuários'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo usuário'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('usuario-nome')), 'Outra Ana');
    await tester.enterText(
      find.byKey(const Key('usuario-email')),
      'ana@exemplo.com',
    );
    await tester.enterText(
      find.byKey(const Key('usuario-senha')),
      'senha-bem-longa',
    );
    await tester.tap(find.byKey(const Key('usuario-salvar')));
    await tester.pumpAndSettle();

    expect(find.text('Já existe um usuário com este e-mail.'), findsOneWidget);
    expect(find.text('Novo usuário'), findsOneWidget);
  });
}
