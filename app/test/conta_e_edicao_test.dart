import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<void> menuDaConta(WidgetTester tester, String opcao) async {
    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(opcao));
    await tester.pumpAndSettle();
  }

  group('trocar senha', () {
    Future<void> preencher(
      WidgetTester tester,
      String atual,
      String nova,
      String repetida,
    ) async {
      await tester.enterText(find.byKey(const Key('senha-atual')), atual);
      await tester.enterText(find.byKey(const Key('senha-nova')), nova);
      await tester.enterText(
        find.byKey(const Key('senha-confirmacao')),
        repetida,
      );
      await tester.tap(find.byKey(const Key('trocar-senha')));
      await tester.pumpAndSettle();
    }

    testeApp('valida, mostra o erro do servidor e passa a usar o token novo', (
      tester,
    ) async {
      await amb.abrirApp(tester);
      await menuDaConta(tester, 'Configurações');
      await tester.tap(find.text('Trocar senha'));
      await tester.pumpAndSettle();

      await preencher(tester, 'senha-antiga', 'nova-senha-1', 'nova-senha-2');
      expect(find.text('As senhas não conferem.'), findsOneWidget);
      await preencher(tester, 'senha-antiga', 'curta', 'curta');
      expect(find.text('Mínimo de 8 caracteres.'), findsOneWidget);
      expect(servidor.pedidos.where((p) => p.contains('/me/senha')), isEmpty);

      await preencher(tester, 'senha-errada', 'nova-senha-1', 'nova-senha-1');
      expect(find.text('A senha atual está incorreta.'), findsOneWidget);
      expect(servidor.senha, 'senha-antiga');

      await preencher(tester, 'senha-antiga', 'nova-senha-1', 'nova-senha-1');
      expect(servidor.senha, 'nova-senha-1');
      expect(amb.cofre.dados['token'], 'tok-novo');
      expect(find.text('Senha trocada.'), findsOneWidget);

      // O token antigo deixou de valer no servidor; o app continua logado
      // porque passou a mandar o novo.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.drag(find.text('Manual do Gol'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('Manual do Gol'), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
    });
  });

  group('filtros da busca', () {
    Future<void> abrirFiltros(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
    }

    testeApp(
      'tipo, modelo (depende da marca) e motor viram parâmetros da busca',
      (tester) async {
        await amb.abrirApp(tester);
        servidor.pedidos.clear();

        await abrirFiltros(tester);
        // Sem marca escolhida não há como escolher modelo.
        expect(find.text('Escolha uma marca antes'), findsOneWidget);
        expect(
          tester
              .widget<ListTile>(find.byKey(const Key('filtro-modelo')))
              .enabled,
          isFalse,
        );

        await tester.tap(find.widgetWithText(ChoiceChip, 'Diagrama elétrico'));
        await tester.pumpAndSettle();
        expect(servidor.pedidos.last, 'GET /documentos?tipo=diagrama_eletrico');

        await tester.tap(find.byKey(const Key('filtro-motor')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EA111 1.6 8v'));
        await tester.pumpAndSettle();
        expect(
          servidor.pedidos.last,
          'GET /documentos?motor_id=20&tipo=diagrama_eletrico',
        );
        expect(find.text('EA111 1.6 8v'), findsOneWidget);

        // Fecha o painel: o selo mostra quantos filtros estão ligados.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(Badge, '2'), findsOneWidget);
        expect(find.text('Nenhum documento encontrado.'), findsOneWidget);

        // Com marca, o modelo fica disponível.
        await tester.tap(find.widgetWithText(FilterChip, 'VW'));
        await tester.pumpAndSettle();
        await abrirFiltros(tester);
        await tester.tap(find.byTooltip('Tirar o filtro de motor'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Diagrama elétrico'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('filtro-modelo')));
        await tester.pumpAndSettle();
        expect(servidor.pedidos.last, 'GET /modelos?marca_id=2');
        await tester.tap(find.text('Gol'));
        await tester.pumpAndSettle();
        expect(
          servidor.pedidos.last,
          'GET /documentos?marca_id=2&modelo_id=10',
        );

        // Trocar de marca desfaz o filtro de modelo.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Fiat'));
        await tester.pumpAndSettle();
        expect(servidor.pedidos.last, 'GET /documentos?marca_id=1');
      },
    );
  });

  group('edição pelo admin', () {
    testeApp('edita o título de um documento', (tester) async {
      await amb.abrirApp(tester);
      await tester.tap(find.text('Manual do Gol'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      // Vem preenchido com o que já existe.
      expect(find.widgetWithText(TextField, 'Manual do Gol'), findsOneWidget);
      expect(find.text('VW Gol'), findsOneWidget);
      expect(find.text('Ignorar'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('titulo')),
        'Manual de serviço do Gol',
      );
      await tester.tap(find.byKey(const Key('salvar')));
      await tester.pumpAndSettle();

      expect(servidor.corpos['PUT /admin/documentos/7'], {
        'titulo': 'Manual de serviço do Gol',
        'tipo': 'manual_servico',
        'veiculo_ids': [7],
        'motor_ids': <int>[],
      });
      // De volta ao detalhe, já com o título novo; e na lista também.
      expect(find.text('Manual de serviço do Gol'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Manual de serviço do Gol'), findsOneWidget);
      expect(find.text('Manual do Gol'), findsNothing);
    });

    testeApp('excluir pede confirmação e volta para a lista', (tester) async {
      await amb.abrirApp(tester);
      await tester.tap(find.text('Esquema do Uno'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(servidor.titulos.containsKey(8), isTrue);

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(servidor.titulos.containsKey(8), isFalse);
      expect(
        find.text('Manuais'),
        findsOneWidget,
        reason: 'voltou para a tela inicial',
      );
      expect(find.text('Esquema do Uno'), findsNothing);
      expect(find.text('Manual do Gol'), findsOneWidget);
    });

    testeApp('mecânico não vê o botão de editar', (tester) async {
      amb.cofre.dados['usuario'] = jsonEncode({
        ...usuarioJson,
        'papel': 'mecanico',
      });
      await amb.abrirApp(tester);
      await tester.tap(find.text('Manual do Gol'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Favoritar'), findsOneWidget);
      expect(find.byTooltip('Editar'), findsNothing);
    });

    testeApp('renomeia marca e mostra o motivo quando não dá para excluir', (
      tester,
    ) async {
      await amb.abrirApp(tester);
      await menuDaConta(tester, 'Administração');
      await tester.tap(find.text('Cadastros'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opções de VW'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo-0')), 'Volkswagen');
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      expect(servidor.marcas[2], 'Volkswagen');
      expect(find.text('Volkswagen'), findsOneWidget);

      // Em uso: o servidor recusa e a marca continua na lista.
      await tester.tap(find.byTooltip('Opções de Volkswagen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(
        find.text('O registro está em uso e não pode ser excluído.'),
        findsOneWidget,
      );
      expect(find.text('Volkswagen'), findsOneWidget);

      // Sem uso: some da lista.
      await tester.tap(find.byTooltip('Opções de Fiat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(servidor.marcas.containsKey(1), isFalse);
      expect(find.text('Fiat'), findsNothing);

      // O filtro de marcas da busca acompanha.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Volkswagen'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Fiat'), findsNothing);
    });
  });
}
