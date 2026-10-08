import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../provedores.dart';

/// O que o usuário pediu na busca. Modelo e motor guardam o objeto inteiro
/// para a tela mostrar o nome do filtro ativo.
class Filtros {
  const Filtros({
    this.q = '',
    this.marcaId,
    this.modelo,
    this.motor,
    this.tipo,
  });

  final String q;
  final int? marcaId;
  final Modelo? modelo;
  final Motor? motor;
  final String? tipo;

  /// Quantos filtros do painel (fora texto e marca) estão ligados.
  int get extras => [modelo, motor, tipo].where((f) => f != null).length;
}

class BuscaEstado {
  const BuscaEstado({
    this.filtros = const Filtros(),
    this.itens = const [],
    this.total = 0,
    this.pagina = 0,
    this.temMais = false,
    this.carregando = false,
    this.erro,
    this.semConexao = false,
  });

  final Filtros filtros;
  final List<Documento> itens;
  final int total;

  /// Última página carregada (0 = nenhuma ainda).
  final int pagina;
  final bool temMais;
  final bool carregando;
  final String? erro;
  final bool semConexao;

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

  void buscar(Filtros filtros) {
    state = BuscaEstado(filtros: filtros, carregando: true);
    _carregar();
  }

  void definirTexto(String q) {
    final f = state.filtros;
    if (q.trim() == f.q.trim()) return;
    buscar(
      Filtros(
        q: q,
        marcaId: f.marcaId,
        modelo: f.modelo,
        motor: f.motor,
        tipo: f.tipo,
      ),
    );
  }

  void definirMarca(int? marcaId) {
    final f = state.filtros;
    if (marcaId == f.marcaId) return;
    // O modelo pertence à marca: trocar a marca desfaz o filtro de modelo.
    buscar(Filtros(q: f.q, marcaId: marcaId, motor: f.motor, tipo: f.tipo));
  }

  void definirExtras({Modelo? modelo, Motor? motor, String? tipo}) {
    final f = state.filtros;
    buscar(
      Filtros(
        q: f.q,
        marcaId: f.marcaId,
        modelo: modelo,
        motor: motor,
        tipo: tipo,
      ),
    );
  }

  Future<void> recarregar() async {
    state = BuscaEstado(filtros: state.filtros, carregando: true);
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
    final f = anterior.filtros;
    try {
      final p = await ref
          .read(apiProvider)
          .documentos(
            q: f.q,
            marcaId: f.marcaId,
            modeloId: f.modelo?.id,
            motorId: f.motor?.id,
            tipo: f.tipo,
            pagina: anterior.pagina + 1,
          );
      if (!ref.mounted || geracao != _geracao) return;
      state = BuscaEstado(
        filtros: f,
        itens: [...anterior.itens, ...p.itens],
        total: p.total,
        pagina: p.pagina,
        temMais: p.temMais,
      );
    } on ApiErro catch (e) {
      if (!ref.mounted || geracao != _geracao) return;
      state = _copiar(
        carregando: false,
        erro: e.mensagem,
        semConexao: e.semConexao,
      );
    }
  }

  BuscaEstado _copiar({
    List<Documento>? itens,
    bool? carregando,
    String? erro,
    bool semConexao = false,
  }) => BuscaEstado(
    filtros: state.filtros,
    itens: itens ?? state.itens,
    total: state.total,
    pagina: state.pagina,
    temMais: state.temMais,
    carregando: carregando ?? state.carregando,
    erro: erro,
    semConexao: semConexao,
  );
}

final buscaProvider = NotifierProvider<BuscaNotifier, BuscaEstado>(
  BuscaNotifier.new,
);
