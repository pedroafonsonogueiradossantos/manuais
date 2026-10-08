import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/api/modelos.dart';
import 'package:manuais/offline/banco_local.dart';

Documento doc(
  int id,
  String titulo, {
  String? md5 = 'm1',
  bool favorito = false,
}) => Documento(
  id: id,
  titulo: titulo,
  tipo: 'manual_servico',
  mimeType: 'application/pdf',
  tamanhoBytes: 10,
  arquivoMd5: md5,
  favorito: favorito,
);

DocumentoDetalhe detalhe(Documento d) => DocumentoDetalhe(
  documento: d,
  veiculos: const [
    Veiculo(
      id: 1,
      marcaNome: 'VW',
      modeloNome: 'Gol',
      motorCodigo: 'EA111',
      anoInicio: 1995,
    ),
  ],
  motores: const [Motor(id: 2, codigo: 'AP', descricao: '1.8')],
);

void main() {
  late BancoLocal banco;

  setUp(() => banco = BancoLocal(NativeDatabase.memory()));
  tearDown(() => banco.close());

  Future<List<String>> baixados([String q = '']) async =>
      (await banco.observarBaixados(q: q).first).map((d) => d.titulo).toList();

  test('normalizar tira acentos e maiúsculas', () {
    expect(normalizar('Injeção ELÉTRICA'), 'injecao eletrica');
  });

  test('baixado guarda arquivo, versão e detalhe para uso offline', () async {
    await banco.marcarBaixado(detalhe(doc(7, 'Manual de Serviço')), '7-m1.pdf');

    final local = (await banco.buscar(7))!;
    expect(local.baixado, isTrue);
    expect(local.arquivoLocal, '7-m1.pdf');
    expect(local.versaoBaixada, 'm1');
    expect(local.detalhe.veiculos.single.rotulo, 'VW Gol · EA111 · desde 1995');
    expect(local.detalhe.motores.single.rotulo, 'AP 1.8');
    expect(local.documento.titulo, 'Manual de Serviço');
  });

  test(
    'busca local casa todas as palavras, sem acento, em título e veículos',
    () async {
      await banco.marcarBaixado(detalhe(doc(7, 'Manual de Serviço')), 'a.pdf');
      await banco.marcarBaixado(
        DocumentoDetalhe(
          documento: doc(8, 'Diagrama da Injeção'),
          veiculos: const [],
          motores: const [],
        ),
        'b.pdf',
      );

      expect(await baixados(), ['Diagrama da Injeção', 'Manual de Serviço']);
      expect(await baixados('servico'), ['Manual de Serviço']);
      expect(await baixados('GOL ea111'), ['Manual de Serviço']);
      expect(await baixados('injeção'), ['Diagrama da Injeção']);
      expect(await baixados('gol injecao'), isEmpty);
    },
  );

  test(
    'remover o arquivo apaga o registro, a menos que seja favorito',
    () async {
      await banco.marcarBaixado(detalhe(doc(7, 'A')), 'a.pdf');
      await banco.marcarBaixado(detalhe(doc(8, 'B', favorito: true)), 'b.pdf');

      await banco.desmarcarBaixado(7);
      await banco.desmarcarBaixado(8);

      expect(await banco.buscar(7), isNull);
      final b = (await banco.buscar(8))!;
      expect(b.baixado, isFalse);
      expect(b.favorito, isTrue);
      expect(await baixados(), isEmpty);
    },
  );

  test(
    'favoritar cria o registro; desfavoritar some se não houver arquivo',
    () async {
      await banco.definirFavorito(doc(7, 'A'), true);
      expect((await banco.observarFavoritos().first).single.titulo, 'A');

      await banco.definirFavorito(doc(7, 'A'), false);
      expect(await banco.buscar(7), isNull);

      // Baixado continua existindo ao desfavoritar.
      await banco.marcarBaixado(detalhe(doc(8, 'B', favorito: true)), 'b.pdf');
      await banco.definirFavorito(doc(8, 'B'), false);
      final b = (await banco.buscar(8))!;
      expect(b.favorito, isFalse);
      expect(b.baixado, isTrue);
      expect(
        b.detalhe.veiculos,
        hasLength(1),
        reason: 'não pode perder o detalhe guardado',
      );
    },
  );

  test(
    'substituirFavoritos espelha o servidor sem perder os baixados',
    () async {
      await banco.definirFavorito(doc(1, 'Antigo'), true);
      await banco.marcarBaixado(
        detalhe(doc(2, 'Baixado e favorito', favorito: true)),
        'b.pdf',
      );

      await banco.substituirFavoritos([doc(3, 'Novo'), doc(4, 'Outro')]);

      expect((await banco.observarFavoritos().first).map((d) => d.titulo), [
        'Novo',
        'Outro',
      ]);
      expect(await banco.buscar(1), isNull);
      final dois = (await banco.buscar(2))!;
      expect(dois.favorito, isFalse);
      expect(dois.baixado, isTrue);

      await banco.substituirFavoritos([]);
      expect(await banco.observarFavoritos().first, isEmpty);
      expect(await baixados(), ['Baixado e favorito']);
    },
  );

  test('atualizarSeExistir não cria registro e mantém o arquivo', () async {
    await banco.atualizarSeExistir(detalhe(doc(7, 'A')));
    expect(await banco.buscar(7), isNull);

    await banco.marcarBaixado(detalhe(doc(7, 'A')), 'a.pdf');
    await banco.atualizarSeExistir(detalhe(doc(7, 'Título novo', md5: 'm2')));

    final local = (await banco.buscar(7))!;
    expect(local.titulo, 'Título novo');
    expect(local.arquivoMd5, 'm2');
    expect(
      local.versaoBaixada,
      'm1',
      reason: 'o arquivo no aparelho ainda é o antigo',
    );
    expect(local.arquivoLocal, 'a.pdf');
    expect(await baixados('novo'), ['Título novo']);
  });

  test('preferências e limpar', () async {
    expect(await banco.preferencia('x'), isNull);
    await banco.definirPreferencia('x', '1');
    await banco.definirPreferencia('x', '2');
    expect(await banco.preferencia('x'), '2');

    await banco.marcarBaixado(detalhe(doc(7, 'A')), 'a.pdf');
    await banco.limpar();
    expect(await banco.preferencia('x'), isNull);
    expect(await banco.buscar(7), isNull);
  });
}
