import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../api/modelos.dart';

part 'banco_local.g.dart';

/// Cópia local do que o usuário precisa sem internet: metadados dos
/// documentos favoritos e baixados, e onde está o arquivo de cada baixado.
@DataClassName('DocumentoLocal')
class DocumentosLocais extends Table {
  /// O mesmo id do servidor.
  IntColumn get id => integer()();
  TextColumn get titulo => text()();
  TextColumn get tipo => text()();
  TextColumn get mimeType => text()();
  IntColumn get tamanhoBytes => integer()();
  TextColumn get arquivoMd5 => text().nullable()();
  DateTimeColumn get arquivoModificadoEm => dateTime().nullable()();
  BoolColumn get favorito => boolean().withDefault(const Constant(false))();

  /// Nome do arquivo na pasta de salvos; nulo = não está baixado.
  TextColumn get arquivoLocal => text().nullable()();

  /// Versão do arquivo que está no aparelho, para saber se o servidor mudou.
  TextColumn get versaoBaixada => text().nullable()();
  DateTimeColumn get baixadoEm => dateTime().nullable()();

  /// Veículos e motores como vieram do servidor, para o detalhe offline.
  TextColumn get detalheJson => text().nullable()();

  /// Título, veículos e motores em minúsculas e sem acento.
  TextColumn get buscaTexto => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class Preferencias extends Table {
  TextColumn get chave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column> get primaryKey => {chave};
}

extension DocumentoLocalX on DocumentoLocal {
  bool get baixado => arquivoLocal != null;

  Documento get documento => Documento(
    id: id,
    titulo: titulo,
    tipo: tipo,
    mimeType: mimeType,
    tamanhoBytes: tamanhoBytes,
    arquivoMd5: arquivoMd5,
    arquivoModificadoEm: arquivoModificadoEm,
    favorito: favorito,
  );

  /// Detalhe guardado na última vez em que o documento foi visto online.
  DocumentoDetalhe get detalhe {
    final extra = detalheJson == null
        ? const <String, dynamic>{}
        : jsonDecode(detalheJson!) as Map<String, dynamic>;
    return DocumentoDetalhe(
      documento: documento,
      veiculos: [
        for (final v in extra['veiculos'] as List? ?? const [])
          Veiculo.fromJson(v as Map<String, dynamic>),
      ],
      motores: [
        for (final m in extra['motores'] as List? ?? const [])
          Motor.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}

const _acentos = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'ê': 'e',
  'è': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Minúsculas e sem acento, para a busca local casar "injecao" com "Injeção".
String normalizar(String texto) =>
    texto.toLowerCase().split('').map((c) => _acentos[c] ?? c).join();

@DriftDatabase(tables: [DocumentosLocais, Preferencias])
class BancoLocal extends _$BancoLocal {
  BancoLocal([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'manuais'));

  @override
  int get schemaVersion => 1;

  DocumentosLocaisCompanion _metadados(Documento d) =>
      DocumentosLocaisCompanion(
        id: Value(d.id),
        titulo: Value(d.titulo),
        tipo: Value(d.tipo),
        mimeType: Value(d.mimeType),
        tamanhoBytes: Value(d.tamanhoBytes),
        arquivoMd5: Value(d.arquivoMd5),
        arquivoModificadoEm: Value(d.arquivoModificadoEm),
      );

  Future<DocumentoLocal?> buscar(int id) => (select(
    documentosLocais,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<DocumentoLocal?> observar(int id) => (select(
    documentosLocais,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Todos os registros locais por id, para marcar "salvo" nas listas.
  Stream<Map<int, DocumentoLocal>> observarTodos() =>
      select(documentosLocais)
          .watch()
          .map((linhas) => {for (final l in linhas) l.id: l});

  /// Baixados cujo texto contém todas as palavras de [q].
  Stream<List<DocumentoLocal>> observarBaixados({String q = ''}) {
    final consulta = select(documentosLocais)
      ..where((t) => t.arquivoLocal.isNotNull())
      ..orderBy([(t) => OrderingTerm(expression: t.titulo)]);
    for (final termo in normalizar(
      q,
    ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty)) {
      consulta.where((t) => t.buscaTexto.contains(termo));
    }
    return consulta.watch();
  }

  Stream<List<DocumentoLocal>> observarFavoritos() =>
      (select(documentosLocais)
            ..where((t) => t.favorito.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.titulo)]))
          .watch();

  /// Atualiza os metadados de um documento que já tem registro local
  /// (não cria registro: só favoritos e baixados ficam guardados).
  Future<void> atualizarSeExistir(DocumentoDetalhe d) async {
    await (update(
      documentosLocais,
    )..where((t) => t.id.equals(d.documento.id))).write(
      _metadados(d.documento).copyWith(
        favorito: Value(d.documento.favorito),
        detalheJson: Value(_detalheJson(d)),
        buscaTexto: Value(_buscaTexto(d)),
      ),
    );
  }

  Future<void> marcarBaixado(DocumentoDetalhe d, String arquivoLocal) async {
    await into(documentosLocais).insertOnConflictUpdate(
      _metadados(d.documento).copyWith(
        favorito: Value(d.documento.favorito),
        arquivoLocal: Value(arquivoLocal),
        versaoBaixada: Value(d.documento.versaoDoArquivo),
        baixadoEm: Value(DateTime.now()),
        detalheJson: Value(_detalheJson(d)),
        buscaTexto: Value(_buscaTexto(d)),
      ),
    );
  }

  /// Esquece o arquivo; o registro só permanece se for favorito.
  Future<void> desmarcarBaixado(int id) => transaction(() async {
    await (update(documentosLocais)..where((t) => t.id.equals(id))).write(
      const DocumentosLocaisCompanion(
        arquivoLocal: Value(null),
        versaoBaixada: Value(null),
        baixadoEm: Value(null),
      ),
    );
    await _limparOrfaos();
  });

  Future<void> definirFavorito(Documento d, bool favorito) => transaction(
    () async {
      final existente = await buscar(d.id);
      if (existente == null && !favorito) return;
      await into(documentosLocais).insertOnConflictUpdate(
        _metadados(d).copyWith(
          favorito: Value(favorito),
          // Sem detalhe ainda: busca só pelo título até o documento ser aberto.
          buscaTexto: existente == null
              ? Value(normalizar(d.titulo))
              : const Value.absent(),
        ),
      );
      await _limparOrfaos();
    },
  );

  /// Troca a lista local de favoritos pela que veio do servidor.
  Future<void> substituirFavoritos(List<Documento> favoritos) =>
      transaction(() async {
        final ids = favoritos.map((d) => d.id).toList();
        await (update(documentosLocais)..where((t) => t.id.isNotIn(ids))).write(
          const DocumentosLocaisCompanion(favorito: Value(false)),
        );
        for (final d in favoritos) {
          final existente = await buscar(d.id);
          await into(documentosLocais).insertOnConflictUpdate(
            _metadados(d).copyWith(
              favorito: const Value(true),
              buscaTexto: existente == null
                  ? Value(normalizar(d.titulo))
                  : const Value.absent(),
            ),
          );
        }
        await _limparOrfaos();
      });

  /// Apaga registros que não são favoritos nem têm arquivo.
  Future<void> _limparOrfaos() => (delete(
    documentosLocais,
  )..where((t) => t.favorito.equals(false) & t.arquivoLocal.isNull())).go();

  /// Apaga tudo (troca de usuário no aparelho).
  Future<void> limpar() => transaction(() async {
    await delete(documentosLocais).go();
    await delete(preferencias).go();
  });

  Future<String?> preferencia(String chave) async => (await (select(
    preferencias,
  )..where((t) => t.chave.equals(chave))).getSingleOrNull())?.valor;

  Future<void> definirPreferencia(String chave, String valor) =>
      into(preferencias).insertOnConflictUpdate(
        PreferenciasCompanion.insert(chave: chave, valor: valor),
      );

  static String _detalheJson(DocumentoDetalhe d) => jsonEncode({
    'veiculos': [for (final v in d.veiculos) v.toJson()],
    'motores': [for (final m in d.motores) m.toJson()],
  });

  static String _buscaTexto(DocumentoDetalhe d) => normalizar(
    [
      d.documento.titulo,
      for (final v in d.veiculos) v.rotulo,
      for (final m in d.motores) m.rotulo,
    ].join(' '),
  );
}
