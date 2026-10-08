// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banco_local.dart';

// ignore_for_file: type=lint
class $DocumentosLocaisTable extends DocumentosLocais
    with TableInfo<$DocumentosLocaisTable, DocumentoLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentosLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
    'titulo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tamanhoBytesMeta = const VerificationMeta(
    'tamanhoBytes',
  );
  @override
  late final GeneratedColumn<int> tamanhoBytes = GeneratedColumn<int>(
    'tamanho_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _arquivoMd5Meta = const VerificationMeta(
    'arquivoMd5',
  );
  @override
  late final GeneratedColumn<String> arquivoMd5 = GeneratedColumn<String>(
    'arquivo_md5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _arquivoModificadoEmMeta =
      const VerificationMeta('arquivoModificadoEm');
  @override
  late final GeneratedColumn<DateTime> arquivoModificadoEm =
      GeneratedColumn<DateTime>(
        'arquivo_modificado_em',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _favoritoMeta = const VerificationMeta(
    'favorito',
  );
  @override
  late final GeneratedColumn<bool> favorito = GeneratedColumn<bool>(
    'favorito',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorito" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _arquivoLocalMeta = const VerificationMeta(
    'arquivoLocal',
  );
  @override
  late final GeneratedColumn<String> arquivoLocal = GeneratedColumn<String>(
    'arquivo_local',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versaoBaixadaMeta = const VerificationMeta(
    'versaoBaixada',
  );
  @override
  late final GeneratedColumn<String> versaoBaixada = GeneratedColumn<String>(
    'versao_baixada',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baixadoEmMeta = const VerificationMeta(
    'baixadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> baixadoEm = GeneratedColumn<DateTime>(
    'baixado_em',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detalheJsonMeta = const VerificationMeta(
    'detalheJson',
  );
  @override
  late final GeneratedColumn<String> detalheJson = GeneratedColumn<String>(
    'detalhe_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _buscaTextoMeta = const VerificationMeta(
    'buscaTexto',
  );
  @override
  late final GeneratedColumn<String> buscaTexto = GeneratedColumn<String>(
    'busca_texto',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titulo,
    tipo,
    mimeType,
    tamanhoBytes,
    arquivoMd5,
    arquivoModificadoEm,
    favorito,
    arquivoLocal,
    versaoBaixada,
    baixadoEm,
    detalheJson,
    buscaTexto,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documentos_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentoLocal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('titulo')) {
      context.handle(
        _tituloMeta,
        titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta),
      );
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('tamanho_bytes')) {
      context.handle(
        _tamanhoBytesMeta,
        tamanhoBytes.isAcceptableOrUnknown(
          data['tamanho_bytes']!,
          _tamanhoBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tamanhoBytesMeta);
    }
    if (data.containsKey('arquivo_md5')) {
      context.handle(
        _arquivoMd5Meta,
        arquivoMd5.isAcceptableOrUnknown(data['arquivo_md5']!, _arquivoMd5Meta),
      );
    }
    if (data.containsKey('arquivo_modificado_em')) {
      context.handle(
        _arquivoModificadoEmMeta,
        arquivoModificadoEm.isAcceptableOrUnknown(
          data['arquivo_modificado_em']!,
          _arquivoModificadoEmMeta,
        ),
      );
    }
    if (data.containsKey('favorito')) {
      context.handle(
        _favoritoMeta,
        favorito.isAcceptableOrUnknown(data['favorito']!, _favoritoMeta),
      );
    }
    if (data.containsKey('arquivo_local')) {
      context.handle(
        _arquivoLocalMeta,
        arquivoLocal.isAcceptableOrUnknown(
          data['arquivo_local']!,
          _arquivoLocalMeta,
        ),
      );
    }
    if (data.containsKey('versao_baixada')) {
      context.handle(
        _versaoBaixadaMeta,
        versaoBaixada.isAcceptableOrUnknown(
          data['versao_baixada']!,
          _versaoBaixadaMeta,
        ),
      );
    }
    if (data.containsKey('baixado_em')) {
      context.handle(
        _baixadoEmMeta,
        baixadoEm.isAcceptableOrUnknown(data['baixado_em']!, _baixadoEmMeta),
      );
    }
    if (data.containsKey('detalhe_json')) {
      context.handle(
        _detalheJsonMeta,
        detalheJson.isAcceptableOrUnknown(
          data['detalhe_json']!,
          _detalheJsonMeta,
        ),
      );
    }
    if (data.containsKey('busca_texto')) {
      context.handle(
        _buscaTextoMeta,
        buscaTexto.isAcceptableOrUnknown(data['busca_texto']!, _buscaTextoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentoLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentoLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      titulo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titulo'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      tamanhoBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tamanho_bytes'],
      )!,
      arquivoMd5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arquivo_md5'],
      ),
      arquivoModificadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}arquivo_modificado_em'],
      ),
      favorito: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorito'],
      )!,
      arquivoLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arquivo_local'],
      ),
      versaoBaixada: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}versao_baixada'],
      ),
      baixadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}baixado_em'],
      ),
      detalheJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detalhe_json'],
      ),
      buscaTexto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}busca_texto'],
      )!,
    );
  }

  @override
  $DocumentosLocaisTable createAlias(String alias) {
    return $DocumentosLocaisTable(attachedDatabase, alias);
  }
}

class DocumentoLocal extends DataClass implements Insertable<DocumentoLocal> {
  /// O mesmo id do servidor.
  final int id;
  final String titulo;
  final String tipo;
  final String mimeType;
  final int tamanhoBytes;
  final String? arquivoMd5;
  final DateTime? arquivoModificadoEm;
  final bool favorito;

  /// Nome do arquivo na pasta de salvos; nulo = não está baixado.
  final String? arquivoLocal;

  /// Versão do arquivo que está no aparelho, para saber se o servidor mudou.
  final String? versaoBaixada;
  final DateTime? baixadoEm;

  /// Veículos e motores como vieram do servidor, para o detalhe offline.
  final String? detalheJson;

  /// Título, veículos e motores em minúsculas e sem acento.
  final String buscaTexto;
  const DocumentoLocal({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.mimeType,
    required this.tamanhoBytes,
    this.arquivoMd5,
    this.arquivoModificadoEm,
    required this.favorito,
    this.arquivoLocal,
    this.versaoBaixada,
    this.baixadoEm,
    this.detalheJson,
    required this.buscaTexto,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['titulo'] = Variable<String>(titulo);
    map['tipo'] = Variable<String>(tipo);
    map['mime_type'] = Variable<String>(mimeType);
    map['tamanho_bytes'] = Variable<int>(tamanhoBytes);
    if (!nullToAbsent || arquivoMd5 != null) {
      map['arquivo_md5'] = Variable<String>(arquivoMd5);
    }
    if (!nullToAbsent || arquivoModificadoEm != null) {
      map['arquivo_modificado_em'] = Variable<DateTime>(arquivoModificadoEm);
    }
    map['favorito'] = Variable<bool>(favorito);
    if (!nullToAbsent || arquivoLocal != null) {
      map['arquivo_local'] = Variable<String>(arquivoLocal);
    }
    if (!nullToAbsent || versaoBaixada != null) {
      map['versao_baixada'] = Variable<String>(versaoBaixada);
    }
    if (!nullToAbsent || baixadoEm != null) {
      map['baixado_em'] = Variable<DateTime>(baixadoEm);
    }
    if (!nullToAbsent || detalheJson != null) {
      map['detalhe_json'] = Variable<String>(detalheJson);
    }
    map['busca_texto'] = Variable<String>(buscaTexto);
    return map;
  }

  DocumentosLocaisCompanion toCompanion(bool nullToAbsent) {
    return DocumentosLocaisCompanion(
      id: Value(id),
      titulo: Value(titulo),
      tipo: Value(tipo),
      mimeType: Value(mimeType),
      tamanhoBytes: Value(tamanhoBytes),
      arquivoMd5: arquivoMd5 == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivoMd5),
      arquivoModificadoEm: arquivoModificadoEm == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivoModificadoEm),
      favorito: Value(favorito),
      arquivoLocal: arquivoLocal == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivoLocal),
      versaoBaixada: versaoBaixada == null && nullToAbsent
          ? const Value.absent()
          : Value(versaoBaixada),
      baixadoEm: baixadoEm == null && nullToAbsent
          ? const Value.absent()
          : Value(baixadoEm),
      detalheJson: detalheJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detalheJson),
      buscaTexto: Value(buscaTexto),
    );
  }

  factory DocumentoLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentoLocal(
      id: serializer.fromJson<int>(json['id']),
      titulo: serializer.fromJson<String>(json['titulo']),
      tipo: serializer.fromJson<String>(json['tipo']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      tamanhoBytes: serializer.fromJson<int>(json['tamanhoBytes']),
      arquivoMd5: serializer.fromJson<String?>(json['arquivoMd5']),
      arquivoModificadoEm: serializer.fromJson<DateTime?>(
        json['arquivoModificadoEm'],
      ),
      favorito: serializer.fromJson<bool>(json['favorito']),
      arquivoLocal: serializer.fromJson<String?>(json['arquivoLocal']),
      versaoBaixada: serializer.fromJson<String?>(json['versaoBaixada']),
      baixadoEm: serializer.fromJson<DateTime?>(json['baixadoEm']),
      detalheJson: serializer.fromJson<String?>(json['detalheJson']),
      buscaTexto: serializer.fromJson<String>(json['buscaTexto']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'titulo': serializer.toJson<String>(titulo),
      'tipo': serializer.toJson<String>(tipo),
      'mimeType': serializer.toJson<String>(mimeType),
      'tamanhoBytes': serializer.toJson<int>(tamanhoBytes),
      'arquivoMd5': serializer.toJson<String?>(arquivoMd5),
      'arquivoModificadoEm': serializer.toJson<DateTime?>(arquivoModificadoEm),
      'favorito': serializer.toJson<bool>(favorito),
      'arquivoLocal': serializer.toJson<String?>(arquivoLocal),
      'versaoBaixada': serializer.toJson<String?>(versaoBaixada),
      'baixadoEm': serializer.toJson<DateTime?>(baixadoEm),
      'detalheJson': serializer.toJson<String?>(detalheJson),
      'buscaTexto': serializer.toJson<String>(buscaTexto),
    };
  }

  DocumentoLocal copyWith({
    int? id,
    String? titulo,
    String? tipo,
    String? mimeType,
    int? tamanhoBytes,
    Value<String?> arquivoMd5 = const Value.absent(),
    Value<DateTime?> arquivoModificadoEm = const Value.absent(),
    bool? favorito,
    Value<String?> arquivoLocal = const Value.absent(),
    Value<String?> versaoBaixada = const Value.absent(),
    Value<DateTime?> baixadoEm = const Value.absent(),
    Value<String?> detalheJson = const Value.absent(),
    String? buscaTexto,
  }) => DocumentoLocal(
    id: id ?? this.id,
    titulo: titulo ?? this.titulo,
    tipo: tipo ?? this.tipo,
    mimeType: mimeType ?? this.mimeType,
    tamanhoBytes: tamanhoBytes ?? this.tamanhoBytes,
    arquivoMd5: arquivoMd5.present ? arquivoMd5.value : this.arquivoMd5,
    arquivoModificadoEm: arquivoModificadoEm.present
        ? arquivoModificadoEm.value
        : this.arquivoModificadoEm,
    favorito: favorito ?? this.favorito,
    arquivoLocal: arquivoLocal.present ? arquivoLocal.value : this.arquivoLocal,
    versaoBaixada: versaoBaixada.present
        ? versaoBaixada.value
        : this.versaoBaixada,
    baixadoEm: baixadoEm.present ? baixadoEm.value : this.baixadoEm,
    detalheJson: detalheJson.present ? detalheJson.value : this.detalheJson,
    buscaTexto: buscaTexto ?? this.buscaTexto,
  );
  DocumentoLocal copyWithCompanion(DocumentosLocaisCompanion data) {
    return DocumentoLocal(
      id: data.id.present ? data.id.value : this.id,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      tamanhoBytes: data.tamanhoBytes.present
          ? data.tamanhoBytes.value
          : this.tamanhoBytes,
      arquivoMd5: data.arquivoMd5.present
          ? data.arquivoMd5.value
          : this.arquivoMd5,
      arquivoModificadoEm: data.arquivoModificadoEm.present
          ? data.arquivoModificadoEm.value
          : this.arquivoModificadoEm,
      favorito: data.favorito.present ? data.favorito.value : this.favorito,
      arquivoLocal: data.arquivoLocal.present
          ? data.arquivoLocal.value
          : this.arquivoLocal,
      versaoBaixada: data.versaoBaixada.present
          ? data.versaoBaixada.value
          : this.versaoBaixada,
      baixadoEm: data.baixadoEm.present ? data.baixadoEm.value : this.baixadoEm,
      detalheJson: data.detalheJson.present
          ? data.detalheJson.value
          : this.detalheJson,
      buscaTexto: data.buscaTexto.present
          ? data.buscaTexto.value
          : this.buscaTexto,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentoLocal(')
          ..write('id: $id, ')
          ..write('titulo: $titulo, ')
          ..write('tipo: $tipo, ')
          ..write('mimeType: $mimeType, ')
          ..write('tamanhoBytes: $tamanhoBytes, ')
          ..write('arquivoMd5: $arquivoMd5, ')
          ..write('arquivoModificadoEm: $arquivoModificadoEm, ')
          ..write('favorito: $favorito, ')
          ..write('arquivoLocal: $arquivoLocal, ')
          ..write('versaoBaixada: $versaoBaixada, ')
          ..write('baixadoEm: $baixadoEm, ')
          ..write('detalheJson: $detalheJson, ')
          ..write('buscaTexto: $buscaTexto')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    titulo,
    tipo,
    mimeType,
    tamanhoBytes,
    arquivoMd5,
    arquivoModificadoEm,
    favorito,
    arquivoLocal,
    versaoBaixada,
    baixadoEm,
    detalheJson,
    buscaTexto,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentoLocal &&
          other.id == this.id &&
          other.titulo == this.titulo &&
          other.tipo == this.tipo &&
          other.mimeType == this.mimeType &&
          other.tamanhoBytes == this.tamanhoBytes &&
          other.arquivoMd5 == this.arquivoMd5 &&
          other.arquivoModificadoEm == this.arquivoModificadoEm &&
          other.favorito == this.favorito &&
          other.arquivoLocal == this.arquivoLocal &&
          other.versaoBaixada == this.versaoBaixada &&
          other.baixadoEm == this.baixadoEm &&
          other.detalheJson == this.detalheJson &&
          other.buscaTexto == this.buscaTexto);
}

class DocumentosLocaisCompanion extends UpdateCompanion<DocumentoLocal> {
  final Value<int> id;
  final Value<String> titulo;
  final Value<String> tipo;
  final Value<String> mimeType;
  final Value<int> tamanhoBytes;
  final Value<String?> arquivoMd5;
  final Value<DateTime?> arquivoModificadoEm;
  final Value<bool> favorito;
  final Value<String?> arquivoLocal;
  final Value<String?> versaoBaixada;
  final Value<DateTime?> baixadoEm;
  final Value<String?> detalheJson;
  final Value<String> buscaTexto;
  const DocumentosLocaisCompanion({
    this.id = const Value.absent(),
    this.titulo = const Value.absent(),
    this.tipo = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.tamanhoBytes = const Value.absent(),
    this.arquivoMd5 = const Value.absent(),
    this.arquivoModificadoEm = const Value.absent(),
    this.favorito = const Value.absent(),
    this.arquivoLocal = const Value.absent(),
    this.versaoBaixada = const Value.absent(),
    this.baixadoEm = const Value.absent(),
    this.detalheJson = const Value.absent(),
    this.buscaTexto = const Value.absent(),
  });
  DocumentosLocaisCompanion.insert({
    this.id = const Value.absent(),
    required String titulo,
    required String tipo,
    required String mimeType,
    required int tamanhoBytes,
    this.arquivoMd5 = const Value.absent(),
    this.arquivoModificadoEm = const Value.absent(),
    this.favorito = const Value.absent(),
    this.arquivoLocal = const Value.absent(),
    this.versaoBaixada = const Value.absent(),
    this.baixadoEm = const Value.absent(),
    this.detalheJson = const Value.absent(),
    this.buscaTexto = const Value.absent(),
  }) : titulo = Value(titulo),
       tipo = Value(tipo),
       mimeType = Value(mimeType),
       tamanhoBytes = Value(tamanhoBytes);
  static Insertable<DocumentoLocal> custom({
    Expression<int>? id,
    Expression<String>? titulo,
    Expression<String>? tipo,
    Expression<String>? mimeType,
    Expression<int>? tamanhoBytes,
    Expression<String>? arquivoMd5,
    Expression<DateTime>? arquivoModificadoEm,
    Expression<bool>? favorito,
    Expression<String>? arquivoLocal,
    Expression<String>? versaoBaixada,
    Expression<DateTime>? baixadoEm,
    Expression<String>? detalheJson,
    Expression<String>? buscaTexto,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titulo != null) 'titulo': titulo,
      if (tipo != null) 'tipo': tipo,
      if (mimeType != null) 'mime_type': mimeType,
      if (tamanhoBytes != null) 'tamanho_bytes': tamanhoBytes,
      if (arquivoMd5 != null) 'arquivo_md5': arquivoMd5,
      if (arquivoModificadoEm != null)
        'arquivo_modificado_em': arquivoModificadoEm,
      if (favorito != null) 'favorito': favorito,
      if (arquivoLocal != null) 'arquivo_local': arquivoLocal,
      if (versaoBaixada != null) 'versao_baixada': versaoBaixada,
      if (baixadoEm != null) 'baixado_em': baixadoEm,
      if (detalheJson != null) 'detalhe_json': detalheJson,
      if (buscaTexto != null) 'busca_texto': buscaTexto,
    });
  }

  DocumentosLocaisCompanion copyWith({
    Value<int>? id,
    Value<String>? titulo,
    Value<String>? tipo,
    Value<String>? mimeType,
    Value<int>? tamanhoBytes,
    Value<String?>? arquivoMd5,
    Value<DateTime?>? arquivoModificadoEm,
    Value<bool>? favorito,
    Value<String?>? arquivoLocal,
    Value<String?>? versaoBaixada,
    Value<DateTime?>? baixadoEm,
    Value<String?>? detalheJson,
    Value<String>? buscaTexto,
  }) {
    return DocumentosLocaisCompanion(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      tipo: tipo ?? this.tipo,
      mimeType: mimeType ?? this.mimeType,
      tamanhoBytes: tamanhoBytes ?? this.tamanhoBytes,
      arquivoMd5: arquivoMd5 ?? this.arquivoMd5,
      arquivoModificadoEm: arquivoModificadoEm ?? this.arquivoModificadoEm,
      favorito: favorito ?? this.favorito,
      arquivoLocal: arquivoLocal ?? this.arquivoLocal,
      versaoBaixada: versaoBaixada ?? this.versaoBaixada,
      baixadoEm: baixadoEm ?? this.baixadoEm,
      detalheJson: detalheJson ?? this.detalheJson,
      buscaTexto: buscaTexto ?? this.buscaTexto,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (tamanhoBytes.present) {
      map['tamanho_bytes'] = Variable<int>(tamanhoBytes.value);
    }
    if (arquivoMd5.present) {
      map['arquivo_md5'] = Variable<String>(arquivoMd5.value);
    }
    if (arquivoModificadoEm.present) {
      map['arquivo_modificado_em'] = Variable<DateTime>(
        arquivoModificadoEm.value,
      );
    }
    if (favorito.present) {
      map['favorito'] = Variable<bool>(favorito.value);
    }
    if (arquivoLocal.present) {
      map['arquivo_local'] = Variable<String>(arquivoLocal.value);
    }
    if (versaoBaixada.present) {
      map['versao_baixada'] = Variable<String>(versaoBaixada.value);
    }
    if (baixadoEm.present) {
      map['baixado_em'] = Variable<DateTime>(baixadoEm.value);
    }
    if (detalheJson.present) {
      map['detalhe_json'] = Variable<String>(detalheJson.value);
    }
    if (buscaTexto.present) {
      map['busca_texto'] = Variable<String>(buscaTexto.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentosLocaisCompanion(')
          ..write('id: $id, ')
          ..write('titulo: $titulo, ')
          ..write('tipo: $tipo, ')
          ..write('mimeType: $mimeType, ')
          ..write('tamanhoBytes: $tamanhoBytes, ')
          ..write('arquivoMd5: $arquivoMd5, ')
          ..write('arquivoModificadoEm: $arquivoModificadoEm, ')
          ..write('favorito: $favorito, ')
          ..write('arquivoLocal: $arquivoLocal, ')
          ..write('versaoBaixada: $versaoBaixada, ')
          ..write('baixadoEm: $baixadoEm, ')
          ..write('detalheJson: $detalheJson, ')
          ..write('buscaTexto: $buscaTexto')
          ..write(')'))
        .toString();
  }
}

class $PreferenciasTable extends Preferencias
    with TableInfo<$PreferenciasTable, Preferencia> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferenciasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chaveMeta = const VerificationMeta('chave');
  @override
  late final GeneratedColumn<String> chave = GeneratedColumn<String>(
    'chave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<String> valor = GeneratedColumn<String>(
    'valor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [chave, valor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferencias';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preferencia> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chave')) {
      context.handle(
        _chaveMeta,
        chave.isAcceptableOrUnknown(data['chave']!, _chaveMeta),
      );
    } else if (isInserting) {
      context.missing(_chaveMeta);
    }
    if (data.containsKey('valor')) {
      context.handle(
        _valorMeta,
        valor.isAcceptableOrUnknown(data['valor']!, _valorMeta),
      );
    } else if (isInserting) {
      context.missing(_valorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chave};
  @override
  Preferencia map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preferencia(
      chave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chave'],
      )!,
      valor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valor'],
      )!,
    );
  }

  @override
  $PreferenciasTable createAlias(String alias) {
    return $PreferenciasTable(attachedDatabase, alias);
  }
}

class Preferencia extends DataClass implements Insertable<Preferencia> {
  final String chave;
  final String valor;
  const Preferencia({required this.chave, required this.valor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chave'] = Variable<String>(chave);
    map['valor'] = Variable<String>(valor);
    return map;
  }

  PreferenciasCompanion toCompanion(bool nullToAbsent) {
    return PreferenciasCompanion(chave: Value(chave), valor: Value(valor));
  }

  factory Preferencia.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preferencia(
      chave: serializer.fromJson<String>(json['chave']),
      valor: serializer.fromJson<String>(json['valor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chave': serializer.toJson<String>(chave),
      'valor': serializer.toJson<String>(valor),
    };
  }

  Preferencia copyWith({String? chave, String? valor}) =>
      Preferencia(chave: chave ?? this.chave, valor: valor ?? this.valor);
  Preferencia copyWithCompanion(PreferenciasCompanion data) {
    return Preferencia(
      chave: data.chave.present ? data.chave.value : this.chave,
      valor: data.valor.present ? data.valor.value : this.valor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preferencia(')
          ..write('chave: $chave, ')
          ..write('valor: $valor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chave, valor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preferencia &&
          other.chave == this.chave &&
          other.valor == this.valor);
}

class PreferenciasCompanion extends UpdateCompanion<Preferencia> {
  final Value<String> chave;
  final Value<String> valor;
  final Value<int> rowid;
  const PreferenciasCompanion({
    this.chave = const Value.absent(),
    this.valor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferenciasCompanion.insert({
    required String chave,
    required String valor,
    this.rowid = const Value.absent(),
  }) : chave = Value(chave),
       valor = Value(valor);
  static Insertable<Preferencia> custom({
    Expression<String>? chave,
    Expression<String>? valor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chave != null) 'chave': chave,
      if (valor != null) 'valor': valor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferenciasCompanion copyWith({
    Value<String>? chave,
    Value<String>? valor,
    Value<int>? rowid,
  }) {
    return PreferenciasCompanion(
      chave: chave ?? this.chave,
      valor: valor ?? this.valor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chave.present) {
      map['chave'] = Variable<String>(chave.value);
    }
    if (valor.present) {
      map['valor'] = Variable<String>(valor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferenciasCompanion(')
          ..write('chave: $chave, ')
          ..write('valor: $valor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BancoLocal extends GeneratedDatabase {
  _$BancoLocal(QueryExecutor e) : super(e);
  $BancoLocalManager get managers => $BancoLocalManager(this);
  late final $DocumentosLocaisTable documentosLocais = $DocumentosLocaisTable(
    this,
  );
  late final $PreferenciasTable preferencias = $PreferenciasTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    documentosLocais,
    preferencias,
  ];
}

typedef $$DocumentosLocaisTableCreateCompanionBuilder =
    DocumentosLocaisCompanion Function({
      Value<int> id,
      required String titulo,
      required String tipo,
      required String mimeType,
      required int tamanhoBytes,
      Value<String?> arquivoMd5,
      Value<DateTime?> arquivoModificadoEm,
      Value<bool> favorito,
      Value<String?> arquivoLocal,
      Value<String?> versaoBaixada,
      Value<DateTime?> baixadoEm,
      Value<String?> detalheJson,
      Value<String> buscaTexto,
    });
typedef $$DocumentosLocaisTableUpdateCompanionBuilder =
    DocumentosLocaisCompanion Function({
      Value<int> id,
      Value<String> titulo,
      Value<String> tipo,
      Value<String> mimeType,
      Value<int> tamanhoBytes,
      Value<String?> arquivoMd5,
      Value<DateTime?> arquivoModificadoEm,
      Value<bool> favorito,
      Value<String?> arquivoLocal,
      Value<String?> versaoBaixada,
      Value<DateTime?> baixadoEm,
      Value<String?> detalheJson,
      Value<String> buscaTexto,
    });

class $$DocumentosLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $DocumentosLocaisTable> {
  $$DocumentosLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tamanhoBytes => $composableBuilder(
    column: $table.tamanhoBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arquivoMd5 => $composableBuilder(
    column: $table.arquivoMd5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get arquivoModificadoEm => $composableBuilder(
    column: $table.arquivoModificadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorito => $composableBuilder(
    column: $table.favorito,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arquivoLocal => $composableBuilder(
    column: $table.arquivoLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versaoBaixada => $composableBuilder(
    column: $table.versaoBaixada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get baixadoEm => $composableBuilder(
    column: $table.baixadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detalheJson => $composableBuilder(
    column: $table.detalheJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get buscaTexto => $composableBuilder(
    column: $table.buscaTexto,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentosLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $DocumentosLocaisTable> {
  $$DocumentosLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tamanhoBytes => $composableBuilder(
    column: $table.tamanhoBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arquivoMd5 => $composableBuilder(
    column: $table.arquivoMd5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get arquivoModificadoEm => $composableBuilder(
    column: $table.arquivoModificadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorito => $composableBuilder(
    column: $table.favorito,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arquivoLocal => $composableBuilder(
    column: $table.arquivoLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versaoBaixada => $composableBuilder(
    column: $table.versaoBaixada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get baixadoEm => $composableBuilder(
    column: $table.baixadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detalheJson => $composableBuilder(
    column: $table.detalheJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get buscaTexto => $composableBuilder(
    column: $table.buscaTexto,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentosLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $DocumentosLocaisTable> {
  $$DocumentosLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get tamanhoBytes => $composableBuilder(
    column: $table.tamanhoBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get arquivoMd5 => $composableBuilder(
    column: $table.arquivoMd5,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get arquivoModificadoEm => $composableBuilder(
    column: $table.arquivoModificadoEm,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get favorito =>
      $composableBuilder(column: $table.favorito, builder: (column) => column);

  GeneratedColumn<String> get arquivoLocal => $composableBuilder(
    column: $table.arquivoLocal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get versaoBaixada => $composableBuilder(
    column: $table.versaoBaixada,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get baixadoEm =>
      $composableBuilder(column: $table.baixadoEm, builder: (column) => column);

  GeneratedColumn<String> get detalheJson => $composableBuilder(
    column: $table.detalheJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get buscaTexto => $composableBuilder(
    column: $table.buscaTexto,
    builder: (column) => column,
  );
}

class $$DocumentosLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $DocumentosLocaisTable,
          DocumentoLocal,
          $$DocumentosLocaisTableFilterComposer,
          $$DocumentosLocaisTableOrderingComposer,
          $$DocumentosLocaisTableAnnotationComposer,
          $$DocumentosLocaisTableCreateCompanionBuilder,
          $$DocumentosLocaisTableUpdateCompanionBuilder,
          (
            DocumentoLocal,
            BaseReferences<
              _$BancoLocal,
              $DocumentosLocaisTable,
              DocumentoLocal
            >,
          ),
          DocumentoLocal,
          PrefetchHooks Function()
        > {
  $$DocumentosLocaisTableTableManager(
    _$BancoLocal db,
    $DocumentosLocaisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentosLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentosLocaisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentosLocaisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> titulo = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> tamanhoBytes = const Value.absent(),
                Value<String?> arquivoMd5 = const Value.absent(),
                Value<DateTime?> arquivoModificadoEm = const Value.absent(),
                Value<bool> favorito = const Value.absent(),
                Value<String?> arquivoLocal = const Value.absent(),
                Value<String?> versaoBaixada = const Value.absent(),
                Value<DateTime?> baixadoEm = const Value.absent(),
                Value<String?> detalheJson = const Value.absent(),
                Value<String> buscaTexto = const Value.absent(),
              }) => DocumentosLocaisCompanion(
                id: id,
                titulo: titulo,
                tipo: tipo,
                mimeType: mimeType,
                tamanhoBytes: tamanhoBytes,
                arquivoMd5: arquivoMd5,
                arquivoModificadoEm: arquivoModificadoEm,
                favorito: favorito,
                arquivoLocal: arquivoLocal,
                versaoBaixada: versaoBaixada,
                baixadoEm: baixadoEm,
                detalheJson: detalheJson,
                buscaTexto: buscaTexto,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String titulo,
                required String tipo,
                required String mimeType,
                required int tamanhoBytes,
                Value<String?> arquivoMd5 = const Value.absent(),
                Value<DateTime?> arquivoModificadoEm = const Value.absent(),
                Value<bool> favorito = const Value.absent(),
                Value<String?> arquivoLocal = const Value.absent(),
                Value<String?> versaoBaixada = const Value.absent(),
                Value<DateTime?> baixadoEm = const Value.absent(),
                Value<String?> detalheJson = const Value.absent(),
                Value<String> buscaTexto = const Value.absent(),
              }) => DocumentosLocaisCompanion.insert(
                id: id,
                titulo: titulo,
                tipo: tipo,
                mimeType: mimeType,
                tamanhoBytes: tamanhoBytes,
                arquivoMd5: arquivoMd5,
                arquivoModificadoEm: arquivoModificadoEm,
                favorito: favorito,
                arquivoLocal: arquivoLocal,
                versaoBaixada: versaoBaixada,
                baixadoEm: baixadoEm,
                detalheJson: detalheJson,
                buscaTexto: buscaTexto,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentosLocaisTable, DocumentoLocal>(table),
                  BaseReferences<
                    _$BancoLocal,
                    $DocumentosLocaisTable,
                    DocumentoLocal
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentosLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $DocumentosLocaisTable,
      DocumentoLocal,
      $$DocumentosLocaisTableFilterComposer,
      $$DocumentosLocaisTableOrderingComposer,
      $$DocumentosLocaisTableAnnotationComposer,
      $$DocumentosLocaisTableCreateCompanionBuilder,
      $$DocumentosLocaisTableUpdateCompanionBuilder,
      (
        DocumentoLocal,
        BaseReferences<_$BancoLocal, $DocumentosLocaisTable, DocumentoLocal>,
      ),
      DocumentoLocal,
      PrefetchHooks Function()
    >;
typedef $$PreferenciasTableCreateCompanionBuilder =
    PreferenciasCompanion Function({
      required String chave,
      required String valor,
      Value<int> rowid,
    });
typedef $$PreferenciasTableUpdateCompanionBuilder =
    PreferenciasCompanion Function({
      Value<String> chave,
      Value<String> valor,
      Value<int> rowid,
    });

class $$PreferenciasTableFilterComposer
    extends Composer<_$BancoLocal, $PreferenciasTable> {
  $$PreferenciasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferenciasTableOrderingComposer
    extends Composer<_$BancoLocal, $PreferenciasTable> {
  $$PreferenciasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferenciasTableAnnotationComposer
    extends Composer<_$BancoLocal, $PreferenciasTable> {
  $$PreferenciasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chave =>
      $composableBuilder(column: $table.chave, builder: (column) => column);

  GeneratedColumn<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);
}

class $$PreferenciasTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $PreferenciasTable,
          Preferencia,
          $$PreferenciasTableFilterComposer,
          $$PreferenciasTableOrderingComposer,
          $$PreferenciasTableAnnotationComposer,
          $$PreferenciasTableCreateCompanionBuilder,
          $$PreferenciasTableUpdateCompanionBuilder,
          (
            Preferencia,
            BaseReferences<_$BancoLocal, $PreferenciasTable, Preferencia>,
          ),
          Preferencia,
          PrefetchHooks Function()
        > {
  $$PreferenciasTableTableManager(_$BancoLocal db, $PreferenciasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferenciasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferenciasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferenciasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> chave = const Value.absent(),
            Value<String> valor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PreferenciasCompanion(chave: chave, valor: valor, rowid: rowid),
          createCompanionCallback:
              ({
                required String chave,
                required String valor,
                Value<int> rowid = const Value.absent(),
              }) => PreferenciasCompanion.insert(
                chave: chave,
                valor: valor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferenciasTable, Preferencia>(table),
                  BaseReferences<_$BancoLocal, $PreferenciasTable, Preferencia>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferenciasTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $PreferenciasTable,
      Preferencia,
      $$PreferenciasTableFilterComposer,
      $$PreferenciasTableOrderingComposer,
      $$PreferenciasTableAnnotationComposer,
      $$PreferenciasTableCreateCompanionBuilder,
      $$PreferenciasTableUpdateCompanionBuilder,
      (
        Preferencia,
        BaseReferences<_$BancoLocal, $PreferenciasTable, Preferencia>,
      ),
      Preferencia,
      PrefetchHooks Function()
    >;

class $BancoLocalManager {
  final _$BancoLocal _db;
  $BancoLocalManager(this._db);
  $$DocumentosLocaisTableTableManager get documentosLocais =>
      $$DocumentosLocaisTableTableManager(_db, _db.documentosLocais);
  $$PreferenciasTableTableManager get preferencias =>
      $$PreferenciasTableTableManager(_db, _db.preferencias);
}
