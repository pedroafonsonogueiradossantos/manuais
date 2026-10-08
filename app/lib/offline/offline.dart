import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../arquivos/arquivo_cache.dart';
import 'banco_local.dart';

const _prefAutoBaixar = 'auto_baixar_favoritos';
const _prefDono = 'usuario_id';

/// Regras do uso offline: salvar e remover arquivos do aparelho, manter a
/// cópia local dos favoritos e baixá-los sozinho quando configurado.
class Offline {
  Offline({
    required this.api,
    required this.banco,
    required this.salvos,
    required this.noWifi,
  });

  final ApiClient api;
  final BancoLocal banco;

  /// Pasta permanente (diferente do cache, que o sistema pode limpar).
  final ArquivoCache salvos;

  /// Diz se a conexão atual é Wi-Fi (ou cabo), isto é, não gasta dados móveis.
  final Future<bool> Function() noWifi;

  bool _baixandoFavoritos = false;

  /// Os dados locais são de um usuário: se outro entrar no mesmo aparelho,
  /// começa do zero.
  Future<void> prepararPara(Usuario usuario) async {
    final dono = await banco.preferencia(_prefDono);
    if (dono == '${usuario.id}') return;
    if (dono != null) {
      await banco.limpar();
      final pasta = await salvos.pasta();
      if (await pasta.exists()) await pasta.delete(recursive: true);
    }
    await banco.definirPreferencia(_prefDono, '${usuario.id}');
  }

  /// Arquivo salvo no aparelho, se existir (mesmo que haja versão mais nova).
  Future<File?> arquivoSalvo(int documentoId) async {
    final local = await banco.buscar(documentoId);
    if (local?.arquivoLocal == null) return null;
    final arquivo = File(
      p.join((await salvos.pasta()).path, local!.arquivoLocal),
    );
    return await arquivo.exists() ? arquivo : null;
  }

  /// Baixa (ou atualiza) o arquivo para uso offline. Lança [ApiErro].
  Future<File> salvar(
    DocumentoDetalhe d, {
    Progresso? aoProgredir,
    CancelToken? cancelamento,
  }) async {
    final anterior = (await banco.buscar(d.documento.id))?.arquivoLocal;
    final arquivo = await salvos.obter(
      d.documento,
      aoProgredir: aoProgredir,
      cancelamento: cancelamento,
    );
    final nome = p.basename(arquivo.path);
    await banco.marcarBaixado(d, nome);
    if (anterior != null && anterior != nome) await _apagar(anterior);
    return arquivo;
  }

  Future<void> remover(int documentoId) async {
    final local = await banco.buscar(documentoId);
    await banco.desmarcarBaixado(documentoId);
    if (local?.arquivoLocal != null) await _apagar(local!.arquivoLocal!);
  }

  Future<void> _apagar(String nome) async {
    final arquivo = File(p.join((await salvos.pasta()).path, nome));
    if (await arquivo.exists()) await arquivo.delete();
  }

  /// Favoritos ficam no servidor; a cópia local é atualizada depois de o
  /// servidor aceitar. Lança [ApiErro] (inclusive sem conexão).
  Future<void> definirFavorito(Documento doc, bool favorito) async {
    await api.definirFavorito(doc.id, favorito);
    await banco.definirFavorito(doc, favorito);
    if (favorito) await baixarFavoritosPendentes();
  }

  /// Traz a lista de favoritos do servidor para o aparelho. Lança [ApiErro].
  Future<void> sincronizarFavoritos() async {
    final todos = <Documento>[];
    for (var pagina = 1; ; pagina++) {
      final r = await api.favoritos(pagina: pagina);
      todos.addAll(r.itens);
      if (!r.temMais) break;
    }
    await banco.substituirFavoritos(todos);
    await baixarFavoritosPendentes();
  }

  Future<bool> autoBaixar() async =>
      await banco.preferencia(_prefAutoBaixar) == '1';

  Future<void> definirAutoBaixar(bool ligado) async {
    await banco.definirPreferencia(_prefAutoBaixar, ligado ? '1' : '0');
    if (ligado) await baixarFavoritosPendentes();
  }

  /// Baixa os favoritos que ainda não estão no aparelho, se a opção estiver
  /// ligada e a rede for Wi-Fi. Falhas são silenciosas: tenta de novo na
  /// próxima sincronização.
  Future<void> baixarFavoritosPendentes() async {
    if (_baixandoFavoritos || !await autoBaixar() || !await noWifi()) return;
    _baixandoFavoritos = true;
    try {
      final favoritos = await banco.observarFavoritos().first;
      for (final f in favoritos.where((f) => !f.baixado)) {
        // O Wi-Fi pode cair no meio de uma fila longa.
        if (!await noWifi()) break;
        try {
          await salvar(await api.documento(f.id));
        } on ApiErro {
          continue;
        }
      }
    } finally {
      _baixandoFavoritos = false;
    }
  }
}
