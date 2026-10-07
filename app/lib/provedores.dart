import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api/api_client.dart';
import 'arquivos/arquivo_cache.dart';
import 'auth/cofre.dart';
import 'auth/sessao.dart';
import 'config.dart';

final cofreProvider = Provider<Cofre>((_) => const CofreSeguro());

/// Só os testes substituem: troca a rede por um adaptador falso.
final adaptadorHttpProvider = Provider<HttpClientAdapter?>((_) => null);

final sessaoProvider = NotifierProvider<SessaoNotifier, Sessao>(
  SessaoNotifier.new,
);

final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: apiUrl,
    // Lido a cada requisição (e não observado) para a API não ser recriada
    // quando a sessão muda.
    token: () => switch (ref.read(sessaoProvider)) {
      SessaoLogada(:final token) => token,
      _ => null,
    },
    aoNaoAutenticado: () => ref.read(sessaoProvider.notifier).sair(),
    adaptador: ref.watch(adaptadorHttpProvider),
  );
});

/// Pasta dos arquivos abertos mas não salvos: o sistema pode limpá-la.
final pastaDeCacheProvider = Provider<Future<Directory> Function()>((_) {
  return () async =>
      Directory(p.join((await getApplicationCacheDirectory()).path, 'documentos'));
});

final arquivoCacheProvider = Provider<ArquivoCache>((ref) {
  return ArquivoCache(
    dio: ref.watch(apiProvider).dio,
    pasta: ref.watch(pastaDeCacheProvider),
  );
});
