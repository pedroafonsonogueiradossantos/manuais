import 'package:dio/dio.dart';

import 'modelos.dart';

/// Erro da API já no formato do backend: {"erro":{"codigo","mensagem"}}.
class ApiErro implements Exception {
  const ApiErro({required this.codigo, required this.mensagem, this.status});

  final String codigo;

  /// Texto pronto para mostrar ao usuário.
  final String mensagem;
  final int? status;

  bool get semConexao => codigo == 'sem_conexao';

  @override
  String toString() => 'ApiErro($status, $codigo): $mensagem';
}

class LoginResultado {
  const LoginResultado({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    required String? Function() token,
    void Function()? aoNaoAutenticado,
    HttpClientAdapter? adaptador,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           // Sem receiveTimeout total: downloads de manuais são longos.
           contentType: Headers.jsonContentType,
         ),
       ) {
    if (adaptador != null) dio.httpClientAdapter = adaptador;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opcoes, handler) {
          final t = token();
          if (t != null) opcoes.headers['Authorization'] = 'Bearer $t';
          handler.next(opcoes);
        },
        onError: (erro, handler) {
          // 401 fora do login = sessão expirada, revogada ou senha trocada.
          if (erro.response?.statusCode == 401 &&
              erro.requestOptions.path != '/auth/login') {
            aoNaoAutenticado?.call();
          }
          handler.next(erro);
        },
      ),
    );
  }

  /// Exposto para o download de arquivos, que precisa de streaming.
  final Dio dio;

  /// Converte qualquer falha do dio em [ApiErro].
  static ApiErro traduzir(Object erro) {
    if (erro is ApiErro) return erro;
    if (erro is DioException) {
      final dados = erro.response?.data;
      if (dados is Map && dados['erro'] is Map) {
        final e = dados['erro'] as Map;
        return ApiErro(
          codigo: '${e['codigo']}',
          mensagem: '${e['mensagem']}',
          status: erro.response?.statusCode,
        );
      }
      if (erro.response == null) {
        return const ApiErro(
          codigo: 'sem_conexao',
          mensagem: 'Sem conexão com o servidor.',
        );
      }
      return ApiErro(
        codigo: 'erro_http',
        mensagem:
            'O servidor respondeu com erro (${erro.response?.statusCode}).',
        status: erro.response?.statusCode,
      );
    }
    return ApiErro(
      codigo: 'erro_desconhecido',
      mensagem: 'Erro inesperado: $erro',
    );
  }

  Future<T> _chamar<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw traduzir(e);
    }
  }

  Future<LoginResultado> login(String email, String senha) => _chamar(() async {
    final r = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'senha': senha},
    );
    return LoginResultado(
      token: r.data!['token'] as String,
      usuario: Usuario.fromJson(r.data!['usuario'] as Map<String, dynamic>),
    );
  });

  Future<Usuario> eu() => _chamar(() async {
    final r = await dio.get<Map<String, dynamic>>('/me');
    return Usuario.fromJson(r.data!);
  });

  Future<List<Marca>> marcas() => _chamar(() async {
    final r = await dio.get<List<dynamic>>('/marcas');
    return [for (final m in r.data!) Marca.fromJson(m as Map<String, dynamic>)];
  });

  Future<Pagina<Documento>> documentos({
    String q = '',
    int? marcaId,
    int? modeloId,
    int? motorId,
    String? tipo,
    int pagina = 1,
  }) => _chamar(() async {
    final r = await dio.get<Map<String, dynamic>>(
      '/documentos',
      queryParameters: {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        'marca_id': ?marcaId,
        'modelo_id': ?modeloId,
        'motor_id': ?motorId,
        'tipo': ?tipo,
        'page': pagina,
      },
    );
    return Pagina.fromJson(r.data!, Documento.fromJson);
  });

  Future<Pagina<Documento>> favoritos({int pagina = 1}) => _chamar(() async {
    final r = await dio.get<Map<String, dynamic>>(
      '/favoritos',
      queryParameters: {'page': pagina},
    );
    return Pagina.fromJson(r.data!, Documento.fromJson);
  });

  /// Devolve o token novo: a troca invalida o atual.
  Future<String> trocarSenha(String atual, String nova) => _chamar(() async {
    final r = await dio.put<Map<String, dynamic>>(
      '/me/senha',
      data: {'senha_atual': atual, 'senha_nova': nova},
    );
    return r.data!['token'] as String;
  });

  Future<DocumentoDetalhe> documento(int id) => _chamar(() async {
    final r = await dio.get<Map<String, dynamic>>('/documentos/$id');
    return DocumentoDetalhe.fromJson(r.data!);
  });

  Future<void> definirFavorito(int documentoId, bool favorito) =>
      _chamar(() async {
        if (favorito) {
          await dio.post<void>('/favoritos/$documentoId');
        } else {
          await dio.delete<void>('/favoritos/$documentoId');
        }
      });

  // ----- administração -----

  Future<Pagina<ArquivoPendente>> pendentes({
    String q = '',
    bool ignorados = false,
    int pagina = 1,
  }) => _chamar(() async {
    final r = await dio.get<Map<String, dynamic>>(
      '/admin/drive/pendentes',
      queryParameters: {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (ignorados) 'ignorados': 'true',
        'page': pagina,
      },
    );
    return Pagina.fromJson(r.data!, ArquivoPendente.fromJson);
  });

  /// Relê a pasta do Drive. Devolve quantos arquivos há e quantos sumiram.
  Future<({int arquivos, int removidos})> sincronizar() => _chamar(() async {
    final r = await dio.post<Map<String, dynamic>>('/admin/drive/sincronizar');
    return (
      arquivos: r.data!['arquivos'] as int,
      removidos: r.data!['removidos'] as int,
    );
  });

  static String caminhoDoPreview(String storageFileId) =>
      '/admin/drive/arquivos/${Uri.encodeComponent(storageFileId)}/preview';

  Future<void> definirIgnorado(String storageFileId, bool ignorado) => _chamar(
    () async {
      final caminho =
          '/admin/drive/arquivos/${Uri.encodeComponent(storageFileId)}/ignorar';
      if (ignorado) {
        await dio.post<void>(caminho);
      } else {
        await dio.delete<void>(caminho);
      }
    },
  );

  Future<Marca> criarMarca(String nome) => _chamar(() async {
    final r = await dio.post<Map<String, dynamic>>(
      '/admin/marcas',
      data: {'nome': nome},
    );
    return Marca.fromJson(r.data!);
  });

  Future<List<Modelo>> modelos(int marcaId) => _chamar(() async {
    final r = await dio.get<List<dynamic>>(
      '/modelos',
      queryParameters: {'marca_id': marcaId},
    );
    return [
      for (final m in r.data!) Modelo.fromJson(m as Map<String, dynamic>),
    ];
  });

  Future<Modelo> criarModelo(int marcaId, String nome) => _chamar(() async {
    final r = await dio.post<Map<String, dynamic>>(
      '/admin/modelos',
      data: {'marca_id': marcaId, 'nome': nome},
    );
    return Modelo.fromJson(r.data!);
  });

  Future<List<Motor>> motores() => _chamar(() async {
    final r = await dio.get<List<dynamic>>('/motores');
    return [for (final m in r.data!) Motor.fromJson(m as Map<String, dynamic>)];
  });

  Future<Motor> criarMotor(String codigo, String descricao) =>
      _chamar(() async {
        final r = await dio.post<Map<String, dynamic>>(
          '/admin/motores',
          data: {'codigo': codigo, 'descricao': descricao},
        );
        return Motor.fromJson(r.data!);
      });

  /// Devolve o id do veículo; se já existir um igual, devolve o existente.
  Future<int> criarVeiculo({
    required int modeloId,
    int? motorId,
    int? anoInicio,
    int? anoFim,
  }) => _chamar(() async {
    final r = await dio.post<Map<String, dynamic>>(
      '/admin/veiculos',
      data: {
        'modelo_id': modeloId,
        'motor_id': motorId,
        'ano_inicio': anoInicio,
        'ano_fim': anoFim,
      },
    );
    return r.data!['id'] as int;
  });

  Future<int> criarDocumento({
    required String titulo,
    required String tipo,
    required String storageFileId,
    required List<int> veiculoIds,
    required List<int> motorIds,
  }) => _chamar(() async {
    final r = await dio.post<Map<String, dynamic>>(
      '/admin/documentos',
      data: {
        'titulo': titulo,
        'tipo': tipo,
        'storage_file_id': storageFileId,
        'veiculo_ids': veiculoIds,
        'motor_ids': motorIds,
      },
    );
    return r.data!['id'] as int;
  });

  Future<void> atualizarDocumento(
    int id, {
    required String titulo,
    required String tipo,
    required List<int> veiculoIds,
    required List<int> motorIds,
  }) => _chamar(() async {
    await dio.put<void>(
      '/admin/documentos/$id',
      data: {
        'titulo': titulo,
        'tipo': tipo,
        'veiculo_ids': veiculoIds,
        'motor_ids': motorIds,
      },
    );
  });

  Future<void> _excluir(String caminho) =>
      _chamar(() => dio.delete<void>(caminho));

  /// O arquivo volta para a fila de pendentes.
  Future<void> excluirDocumento(int id) => _excluir('/admin/documentos/$id');

  Future<void> renomearMarca(int id, String nome) =>
      _chamar(() => dio.put<void>('/admin/marcas/$id', data: {'nome': nome}));

  Future<void> excluirMarca(int id) => _excluir('/admin/marcas/$id');

  Future<void> renomearModelo(Modelo m, String nome) => _chamar(
    () => dio.put<void>(
      '/admin/modelos/${m.id}',
      data: {'marca_id': m.marcaId, 'nome': nome},
    ),
  );

  Future<void> excluirModelo(int id) => _excluir('/admin/modelos/$id');

  Future<void> atualizarMotor(int id, String codigo, String descricao) =>
      _chamar(
        () => dio.put<void>(
          '/admin/motores/$id',
          data: {'codigo': codigo, 'descricao': descricao},
        ),
      );

  Future<void> excluirMotor(int id) => _excluir('/admin/motores/$id');

  Future<List<Veiculo>> veiculos(int modeloId) => _chamar(() async {
    final r = await dio.get<List<dynamic>>(
      '/veiculos',
      queryParameters: {'modelo_id': modeloId},
    );
    return [
      for (final v in r.data!) Veiculo.fromJson(v as Map<String, dynamic>),
    ];
  });

  Future<void> excluirVeiculo(int id) => _excluir('/admin/veiculos/$id');

  Future<List<Usuario>> usuarios() => _chamar(() async {
    final r = await dio.get<List<dynamic>>('/admin/usuarios');
    return [
      for (final u in r.data!) Usuario.fromJson(u as Map<String, dynamic>),
    ];
  });

  /// [id] nulo cria; senão atualiza. Senha vazia na edição mantém a atual.
  Future<Usuario> salvarUsuario({
    int? id,
    required String nome,
    required String email,
    required String papel,
    required bool ativo,
    String senha = '',
  }) => _chamar(() async {
    final dados = {
      'nome': nome,
      'email': email,
      'papel': papel,
      'ativo': ativo,
      if (senha.isNotEmpty) 'senha': senha,
    };
    final r = id == null
        ? await dio.post<Map<String, dynamic>>('/admin/usuarios', data: dados)
        : await dio.put<Map<String, dynamic>>(
            '/admin/usuarios/$id',
            data: dados,
          );
    return Usuario.fromJson(r.data!);
  });
}
