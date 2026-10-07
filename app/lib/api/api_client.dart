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
        mensagem: 'O servidor respondeu com erro (${erro.response?.statusCode}).',
        status: erro.response?.statusCode,
      );
    }
    return ApiErro(codigo: 'erro_desconhecido', mensagem: 'Erro inesperado: $erro');
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
    int pagina = 1,
  }) => _chamar(() async {
    final r = await dio.get<Map<String, dynamic>>(
      '/documentos',
      queryParameters: {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        'marca_id': ?marcaId,
        'page': pagina,
      },
    );
    return Pagina.fromJson(r.data!, Documento.fromJson);
  });

  Future<DocumentoDetalhe> documento(int id) => _chamar(() async {
    final r = await dio.get<Map<String, dynamic>>('/documentos/$id');
    return DocumentoDetalhe.fromJson(r.data!);
  });

  Future<void> definirFavorito(int documentoId, bool favorito) => _chamar(() async {
    if (favorito) {
      await dio.post<void>('/favoritos/$documentoId');
    } else {
      await dio.delete<void>('/favoritos/$documentoId');
    }
  });
}
