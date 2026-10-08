import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api/api_client.dart';
import 'api/modelos.dart';
import 'arquivos/arquivo_cache.dart';
import 'auth/cofre.dart';
import 'auth/sessao.dart';
import 'config.dart';
import 'offline/banco_local.dart';
import 'offline/offline.dart';

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

/// Marcas mostradas como filtro na busca.
final marcasDoFiltroProvider = FutureProvider<List<Marca>>(
  (ref) => ref.watch(apiProvider).marcas(),
);

/// Pasta dos arquivos abertos mas não salvos: o sistema pode limpá-la.
final pastaDeCacheProvider = Provider<Future<Directory> Function()>((_) {
  return () async => Directory(
    p.join((await getApplicationCacheDirectory()).path, 'documentos'),
  );
});

final arquivoCacheProvider = Provider<ArquivoCache>((ref) {
  return ArquivoCache(
    dio: ref.watch(apiProvider).dio,
    pasta: ref.watch(pastaDeCacheProvider),
  );
});

final bancoLocalProvider = Provider<BancoLocal>((ref) {
  final banco = BancoLocal();
  ref.onDispose(banco.close);
  return banco;
});

/// Pasta dos arquivos salvos para uso offline: o sistema não a limpa.
final pastaDeSalvosProvider = Provider<Future<Directory> Function()>((_) {
  return () async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'documentos'),
  );
});

final noWifiProvider = Provider<Future<bool> Function()>((_) {
  return () async {
    final redes = await Connectivity().checkConnectivity();
    return redes.contains(ConnectivityResult.wifi) ||
        redes.contains(ConnectivityResult.ethernet);
  };
});

final offlineProvider = Provider<Offline>((ref) {
  final api = ref.watch(apiProvider);
  return Offline(
    api: api,
    banco: ref.watch(bancoLocalProvider),
    salvos: ArquivoCache(dio: api.dio, pasta: ref.watch(pastaDeSalvosProvider)),
    noWifi: ref.watch(noWifiProvider),
  );
});

/// Registros locais por id do documento, para marcar "salvo" nas listas.
final locaisProvider = StreamProvider<Map<int, DocumentoLocal>>(
  (ref) => ref.watch(bancoLocalProvider).observarTodos(),
);
