class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.papel,
  });

  final int id;
  final String nome;
  final String email;
  final String papel;

  bool get admin => papel == 'admin';

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
    id: j['id'] as int,
    nome: j['nome'] as String,
    email: j['email'] as String,
    papel: j['papel'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'email': email,
    'papel': papel,
  };
}

class Marca {
  const Marca({required this.id, required this.nome});

  final int id;
  final String nome;

  factory Marca.fromJson(Map<String, dynamic> j) =>
      Marca(id: j['id'] as int, nome: j['nome'] as String);
}

class Motor {
  const Motor({required this.id, required this.codigo, required this.descricao});

  final int id;
  final String codigo;
  final String descricao;

  String get rotulo => descricao.isEmpty ? codigo : '$codigo $descricao';

  factory Motor.fromJson(Map<String, dynamic> j) => Motor(
    id: j['id'] as int,
    codigo: j['codigo'] as String,
    descricao: j['descricao'] as String? ?? '',
  );
}

/// Veículo como vem nas listagens: já com os nomes de marca, modelo e motor.
class Veiculo {
  const Veiculo({
    required this.id,
    required this.marcaNome,
    required this.modeloNome,
    this.motorCodigo,
    this.motorDescricao,
    this.anoInicio,
    this.anoFim,
  });

  final int id;
  final String marcaNome;
  final String modeloNome;
  final String? motorCodigo;
  final String? motorDescricao;
  final int? anoInicio;
  final int? anoFim;

  /// Ex.: "VW Gol · EA111 1.6 8v · 1995–2005".
  String get rotulo {
    final partes = ['$marcaNome $modeloNome'];
    final motor = [motorCodigo, motorDescricao]
        .where((p) => p != null && p.isNotEmpty)
        .join(' ');
    if (motor.isNotEmpty) partes.add(motor);
    if (anoInicio != null && anoFim != null) {
      partes.add(anoInicio == anoFim ? '$anoInicio' : '$anoInicio–$anoFim');
    } else if (anoInicio != null) {
      partes.add('desde $anoInicio');
    } else if (anoFim != null) {
      partes.add('até $anoFim');
    }
    return partes.join(' · ');
  }

  factory Veiculo.fromJson(Map<String, dynamic> j) => Veiculo(
    id: j['id'] as int,
    marcaNome: j['marca_nome'] as String,
    modeloNome: j['modelo_nome'] as String,
    motorCodigo: j['motor_codigo'] as String?,
    motorDescricao: j['motor_descricao'] as String?,
    anoInicio: j['ano_inicio'] as int?,
    anoFim: j['ano_fim'] as int?,
  );
}

class Documento {
  const Documento({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.mimeType,
    required this.tamanhoBytes,
    this.arquivoMd5,
    this.arquivoModificadoEm,
    this.indisponivel = false,
    this.favorito = false,
  });

  final int id;
  final String titulo;
  final String tipo;
  final String mimeType;
  final int tamanhoBytes;
  final String? arquivoMd5;
  final DateTime? arquivoModificadoEm;

  /// O arquivo sumiu do armazenamento.
  final bool indisponivel;
  final bool favorito;

  bool get ehPdf => mimeType == 'application/pdf';
  bool get ehImagem => mimeType.startsWith('image/');

  /// Identifica o conteúdo do arquivo: muda quando o arquivo é substituído.
  String get versaoDoArquivo =>
      arquivoMd5 ??
      arquivoModificadoEm?.millisecondsSinceEpoch.toString() ??
      'sem-versao';

  Documento copiarCom({bool? favorito}) => Documento(
    id: id,
    titulo: titulo,
    tipo: tipo,
    mimeType: mimeType,
    tamanhoBytes: tamanhoBytes,
    arquivoMd5: arquivoMd5,
    arquivoModificadoEm: arquivoModificadoEm,
    indisponivel: indisponivel,
    favorito: favorito ?? this.favorito,
  );

  factory Documento.fromJson(Map<String, dynamic> j) => Documento(
    id: j['id'] as int,
    titulo: j['titulo'] as String,
    tipo: j['tipo'] as String,
    mimeType: j['mime_type'] as String,
    tamanhoBytes: j['tamanho_bytes'] as int,
    arquivoMd5: j['arquivo_md5'] as String?,
    arquivoModificadoEm: j['arquivo_modificado_em'] == null
        ? null
        : DateTime.parse(j['arquivo_modificado_em'] as String),
    indisponivel: j['indisponivel'] as bool? ?? false,
    favorito: j['favorito'] as bool? ?? false,
  );
}

class DocumentoDetalhe {
  const DocumentoDetalhe({
    required this.documento,
    required this.veiculos,
    required this.motores,
  });

  final Documento documento;
  final List<Veiculo> veiculos;
  final List<Motor> motores;

  factory DocumentoDetalhe.fromJson(Map<String, dynamic> j) => DocumentoDetalhe(
    documento: Documento.fromJson(j),
    veiculos: [
      for (final v in j['veiculos'] as List? ?? const [])
        Veiculo.fromJson(v as Map<String, dynamic>),
    ],
    motores: [
      for (final m in j['motores'] as List? ?? const [])
        Motor.fromJson(m as Map<String, dynamic>),
    ],
  );
}

class Pagina<T> {
  const Pagina({
    required this.itens,
    required this.total,
    required this.pagina,
    required this.porPagina,
  });

  final List<T> itens;
  final int total;
  final int pagina;
  final int porPagina;

  bool get temMais => pagina * porPagina < total;

  factory Pagina.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) item,
  ) => Pagina(
    itens: [
      for (final i in j['itens'] as List) item(i as Map<String, dynamic>),
    ],
    total: j['total'] as int,
    pagina: j['pagina'] as int,
    porPagina: j['por_pagina'] as int,
  );
}
