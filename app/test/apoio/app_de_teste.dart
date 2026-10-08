import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/main.dart';
import 'package:manuais/offline/banco_local.dart';
import 'package:manuais/provedores.dart';

import 'adaptador_falso.dart';
import 'cofre_memoria.dart';

/// Tudo o que o app toca fora dele, trocado por versões de teste: rede,
/// cofre, banco local (em memória) e pastas (temporárias).
class AmbienteDeTeste {
  AmbienteDeTeste(this.responder) {
    _atual = this;
  }

  final Future<ResponseBody> Function(RequestOptions) responder;
  final cofre = CofreMemoria();
  final banco = BancoLocal(NativeDatabase.memory());
  final Directory pasta = Directory.systemTemp.createTempSync('app_teste');
  bool wifi = true;

  Directory get cache => Directory('${pasta.path}/cache');
  Directory get salvos => Directory('${pasta.path}/salvos');

  Future<void> abrirApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Chave nova a cada abertura: simula fechar e abrir o app.
        key: UniqueKey(),
        overrides: [
          cofreProvider.overrideWithValue(cofre),
          adaptadorHttpProvider.overrideWithValue(AdaptadorFalso(responder)),
          bancoLocalProvider.overrideWithValue(banco),
          pastaDeCacheProvider.overrideWithValue(() async => cache),
          pastaDeSalvosProvider.overrideWithValue(() async => salvos),
          noWifiProvider.overrideWithValue(() async => wifi),
        ],
        child: const ManuaisApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Arquivos prontos (sem os `.part`) em [pasta].
  static List<String> arquivosEm(Directory pasta) => pasta.existsSync()
      ? (pasta
            .listSync()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => !n.endsWith('.part'))
            .toList()
          ..sort())
      : [];

  /// Executa [acao] com E/S real (downloads gravam em disco de verdade) e
  /// espera [ate] ficar verdadeiro, depois atualiza a tela.
  Future<void> comDisco(
    WidgetTester tester,
    Future<void> Function() acao, {
    required bool Function() ate,
  }) async {
    await tester.runAsync(() async {
      await acao();
      for (var i = 0; i < 100 && !ate(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // Tempo para o que vem depois do arquivo pronto (gravar no banco).
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Desmonta o app e libera banco e arquivos.
  Future<void> encerrar(WidgetTester tester) async {
    _atual = null;
    await tester.pumpWidget(const SizedBox());
    // O drift fecha as consultas observadas com um timer.
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await banco.close();
      if (pasta.existsSync()) pasta.deleteSync(recursive: true);
    });
  }
}

AmbienteDeTeste? _atual;

/// testWidgets que encerra o ambiente ainda dentro do corpo do teste: o
/// framework confere timers pendentes antes de rodar os tearDowns.
void testeApp(String descricao, Future<void> Function(WidgetTester) corpo) {
  testWidgets(descricao, (tester) async {
    try {
      await corpo(tester);
    } finally {
      await _atual?.encerrar(tester);
    }
  });
}
