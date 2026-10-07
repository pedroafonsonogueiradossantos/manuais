import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../provedores.dart';

final marcasProvider = FutureProvider<List<Marca>>(
  (ref) => ref.watch(apiProvider).marcas(),
);

class BuscaEstado {
  const BuscaEstado({
    this.q = '',
    this.marcaId,
    this.itens = const [],
    this.total = 0,
    this.pagina = 0,
    this.temMais = false,
    this.carregando = false,
    this.erro,
  });

  final String q;
  final int? marcaId;
  final List<Documento> itens;
  final int total;

  /// Última página carregada (0 = nenhuma ainda).
  final int pagina;
  final bool temMais;
  final bool carregando;
  final String? erro;

  /// Primeira carga ou troca de filtro: ainda não há o que mostrar.
  bool get carregandoDoZero => carregando && pagina == 0;
}

class BuscaNotifier extends Notifier<BuscaEstado> {
  /// Cada busca nova invalida as respostas das anteriores que ainda estão
  /// a caminho (o usuário continuou digitando).
  int _geracao = 0;

  @override
  BuscaEstado build() {
    Future.microtask(_carregar);
    return const BuscaEstado(carregando: true);
  }

  void buscar({required String q, required int? marcaId}) {
    state = BuscaEstado(q: q, marcaId: marcaId, carregando: true);
    _carregar();
  }

  void definirTexto(String q) {
    if (q.trim() == state.q.trim()) return;
    buscar(q: q, marcaId: state.marcaId);
  }

  void definirMarca(int? marcaId) {
    if (marcaId == state.marcaId) return;
    buscar(q: state.q, marcaId: marcaId);
  }

  Future<void> recarregar() async {
    state = BuscaEstado(q: state.q, marcaId: state.marcaId, carregando: true);
    await _carregar();
  }

  Future<void> carregarMais() async {
    if (state.carregando || !state.temMais) return;
    state = _copiar(carregando: true);
    await _carregar();
  }

  /// Reflete na lista uma mudança de favorito feita em outra tela.
  void atualizarFavorito(int documentoId, bool favorito) {
    state = _copiar(
      itens: [
        for (final d in state.itens)
          d.id == documentoId ? d.copiarCom(favorito: favorito) : d,
      ],
    );
  }

  Future<void> _carregar() async {
    final geracao = ++_geracao;
    final anterior = state;
    try {
      final p = await ref
          .read(apiProvider)
          .documentos(q: anterior.q, marcaId: anterior.marcaId, pagina: anterior.pagina + 1);
      if (!ref.mounted || geracao != _geracao) return;
      state = BuscaEstado(
        q: anterior.q,
        marcaId: anterior.marcaId,
        itens: [...anterior.itens, ...p.itens],
        total: p.total,
        pagina: p.pagina,
        temMais: p.temMais,
      );
    } on ApiErro catch (e) {
      if (!ref.mounted || geracao != _geracao) return;
      state = _copiar(carregando: false, erro: e.mensagem);
    }
  }

  BuscaEstado _copiar({List<Documento>? itens, bool? carregando, String? erro}) =>
      BuscaEstado(
        q: state.q,
        marcaId: state.marcaId,
        itens: itens ?? state.itens,
        total: state.total,
        pagina: state.pagina,
        temMais: state.temMais,
        carregando: carregando ?? state.carregando,
        erro: erro,
      );
}

final buscaProvider = NotifierProvider<BuscaNotifier, BuscaEstado>(BuscaNotifier.new);
