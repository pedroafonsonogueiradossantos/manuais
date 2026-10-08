import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/arquivos/visualizador_page.dart';

import 'apoio/adaptador_falso.dart';
import 'apoio/app_de_teste.dart';
import 'apoio/servidor_falso.dart';

void main() {
  late ServidorFalso servidor;
  late AmbienteDeTeste amb;

  setUp(() {
    servidor = ServidorFalso();
    amb = AmbienteDeTeste(servidor.responder);
    amb.cofre.dados['token'] = 'tok';
    amb.cofre.dados['usuario'] = jsonEncode(usuarioJson);
  });

  List<String> salvos() => AmbienteDeTeste.arquivosEm(amb.salvos);

  Future<void> irPara(WidgetTester tester, String aba) async {
    await tester.tap(find.widgetWithText(NavigationDestination, aba));
    await tester.pumpAndSettle();
  }

  Future<void> abrirDocumento(WidgetTester tester, String titulo) async {
    await tester.tap(find.text(titulo).last);
    await tester.pumpAndSettle();
  }

  Future<void> salvarOffline(WidgetTester tester, {int esperados = 1}) async {
    await amb.comDisco(
      tester,
      () => tester.tap(find.byKey(const Key('salvar-offline'))),
      ate: () => salvos().length >= esperados,
    );
    await tester.pumpAndSettle();
  }

  Future<void> voltar(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  testeApp(
    'salvar offline marca a lista, aparece em Baixados e dá para remover',
    (tester) async {
      await amb.abrirApp(tester);
      await abrirDocumento(tester, 'Manual do Gol');
      expect(find.byKey(const Key('remover-offline')), findsNothing);

      await salvarOffline(tester);

      expect(salvos(), ['7-v1.png']);
      expect(find.text('Salvo no aparelho.'), findsOneWidget);
      expect(find.byKey(const Key('remover-offline')), findsOneWidget);
      expect(find.byKey(const Key('salvar-offline')), findsNothing);

      await voltar(tester);
      expect(find.byTooltip('Salvo no aparelho'), findsOneWidget);

      await irPara(tester, 'Baixados');
      expect(find.textContaining('1 documento ·'), findsOneWidget);
      expect(find.text('Manual do Gol'), findsWidgets);

      // Busca local por veículo, sem acento nem maiúsculas.
      await tester.enterText(find.byKey(const Key('busca-baixados')), 'uno');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum baixado com esse texto.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('busca-baixados')), 'vw GOL');
      await tester.pumpAndSettle();
      expect(find.textContaining('1 documento ·'), findsOneWidget);

      await tester.tap(find.byTooltip('Remover do aparelho'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();
      // Apagar o arquivo é E/S real.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(salvos(), isEmpty);
      expect(find.textContaining('1 documento ·'), findsNothing);
    },
  );

  testeApp('sem internet: baixados abrem, a busca avisa e o resto é recusado', (
    tester,
  ) async {
    await amb.abrirApp(tester);
    await abrirDocumento(tester, 'Manual do Gol');
    await salvarOffline(tester);
    await voltar(tester);

    // Fecha o app, cai a rede, abre de novo.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    servidor.semRede = true;
    await amb.abrirApp(tester);

    expect(find.textContaining('Sem conexão com o servidor.'), findsOneWidget);
    expect(find.textContaining('aba Baixados'), findsOneWidget);

    await irPara(tester, 'Baixados');
    await abrirDocumento(tester, 'Manual do Gol');

    expect(
      find.text('Sem conexão. Mostrando a cópia salva no aparelho.'),
      findsOneWidget,
    );
    expect(
      find.text('VW Gol'),
      findsOneWidget,
      reason: 'veículos vêm da cópia local',
    );
    expect(find.byTooltip('Editar'), findsNothing);

    // Abre o arquivo local sem pedir nada ao servidor.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('abrir')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(VisualizadorPage), findsOneWidget);
    await voltar(tester);

    // Favoritar precisa do servidor.
    await tester.tap(find.byTooltip('Favoritar'));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
    expect(find.byTooltip('Favoritar'), findsOneWidget);
  });

  testeApp('arquivo trocado no servidor oferece atualizar', (tester) async {
    await amb.abrirApp(tester);
    await abrirDocumento(tester, 'Manual do Gol');
    await salvarOffline(tester);
    expect(find.text('Há uma versão mais nova deste arquivo.'), findsNothing);
    await voltar(tester);

    servidor.md5[7] = 'v2';
    await abrirDocumento(tester, 'Manual do Gol');
    expect(find.text('Há uma versão mais nova deste arquivo.'), findsOneWidget);

    await amb.comDisco(
      tester,
      () => tester.tap(find.text('Atualizar')),
      ate: () => salvos().contains('7-v2.png'),
    );
    await tester.pumpAndSettle();

    expect(salvos(), ['7-v2.png'], reason: 'a versão antiga é apagada');
    expect(find.text('Há uma versão mais nova deste arquivo.'), findsNothing);
    expect(find.text('Arquivo atualizado.'), findsOneWidget);
  });

  testeApp('favoritos ficam no servidor e continuam visíveis sem internet', (
    tester,
  ) async {
    servidor.favoritos.add(8);
    await amb.abrirApp(tester);

    // Sincronizado ao abrir.
    await irPara(tester, 'Favoritos');
    expect(find.text('Esquema do Uno'), findsWidgets);

    await irPara(tester, 'Buscar');
    await abrirDocumento(tester, 'Manual do Gol');
    await tester.tap(find.byTooltip('Favoritar'));
    await tester.pumpAndSettle();
    expect(servidor.favoritos, {7, 8});
    expect(find.byTooltip('Remover dos favoritos'), findsOneWidget);
    await voltar(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    servidor.semRede = true;
    await amb.abrirApp(tester);
    await irPara(tester, 'Favoritos');

    expect(find.text('Manual do Gol'), findsOneWidget);
    expect(find.text('Esquema do Uno'), findsOneWidget);
  });

  testeApp('download automático de favoritos respeita a opção e o Wi-Fi', (
    tester,
  ) async {
    servidor.favoritos.addAll({7, 8});
    amb.wifi = false;
    await amb.abrirApp(tester);
    expect(salvos(), isEmpty, reason: 'a opção começa desligada');

    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();

    // Ligada, mas em dados móveis: não baixa.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('auto-baixar')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('auto-baixar'))).value,
      isTrue,
    );
    expect(salvos(), isEmpty);

    // No Wi-Fi, religar a opção baixa os dois.
    amb.wifi = true;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('auto-baixar')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await amb.comDisco(
      tester,
      () => tester.tap(find.byKey(const Key('auto-baixar'))),
      ate: () => salvos().length == 2,
    );

    expect(salvos(), ['7-v1.png', '8-v1.png']);
  });
}
