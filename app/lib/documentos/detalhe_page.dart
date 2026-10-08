import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/catalogar_page.dart';
import '../api/api_client.dart';
import '../api/modelos.dart';
import '../arquivos/visualizador_page.dart';
import '../auth/sessao.dart';
import '../comum/avisos.dart';
import '../offline/banco_local.dart';
import '../provedores.dart';
import '../util/formatos.dart';
import 'busca.dart';

/// Detalhe do servidor ou, sem conexão, a cópia guardada no aparelho.
typedef DetalheCarregado = ({DocumentoDetalhe detalhe, bool offline});

final documentoProvider = FutureProvider.autoDispose
    .family<DetalheCarregado, int>((ref, id) async {
      final banco = ref.watch(bancoLocalProvider);
      try {
        final detalhe = await ref.watch(apiProvider).documento(id);
        // Mantém a cópia local em dia (título, veículos, versão do arquivo).
        await banco.atualizarSeExistir(detalhe);
        return (detalhe: detalhe, offline: false);
      } on ApiErro catch (e) {
        final local = e.semConexao ? await banco.buscar(id) : null;
        if (local == null) rethrow;
        return (detalhe: local.detalhe, offline: true);
      }
    });

final _localProvider = StreamProvider.autoDispose.family<DocumentoLocal?, int>(
  (ref, id) => ref.watch(bancoLocalProvider).observar(id),
);

enum _Operacao { abrindo, salvando }

class DetalhePage extends ConsumerStatefulWidget {
  const DetalhePage({super.key, required this.documentoId});

  final int documentoId;

  @override
  ConsumerState<DetalhePage> createState() => _DetalhePageState();
}

class _DetalhePageState extends ConsumerState<DetalhePage> {
  /// Download em andamento e sua fração (0 a 1).
  _Operacao? _operacao;
  double _progresso = 0;
  CancelToken? _cancelamento;

  @override
  void dispose() {
    _cancelamento?.cancel();
    super.dispose();
  }

  /// Roda um download mostrando progresso; devolve null se falhar ou for
  /// cancelado (o erro já foi mostrado).
  Future<File?> _baixar(
    _Operacao operacao,
    Future<File> Function(void Function(int, int) aoProgredir, CancelToken c)
    acao,
  ) async {
    if (_operacao != null) return null;
    final cancelamento = _cancelamento = CancelToken();
    setState(() {
      _operacao = operacao;
      _progresso = 0;
    });
    try {
      return await acao((recebido, total) {
        if (mounted && total > 0) setState(() => _progresso = recebido / total);
      }, cancelamento);
    } on ApiErro catch (e) {
      if (mounted && !cancelamento.isCancelled) avisar(context, e.mensagem);
      return null;
    } finally {
      if (mounted) setState(() => _operacao = null);
    }
  }

  Future<void> _abrir(Documento doc) async {
    // Salvo no aparelho abre direto, com ou sem internet.
    var arquivo = await ref.read(offlineProvider).arquivoSalvo(doc.id);
    arquivo ??= await _baixar(
      _Operacao.abrindo,
      (progresso, c) => ref
          .read(arquivoCacheProvider)
          .obter(doc, aoProgredir: progresso, cancelamento: c),
    );
    if (arquivo == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisualizadorPage.doDocumento(doc, arquivo!),
      ),
    );
  }

  Future<void> _salvar(DocumentoDetalhe d, {bool atualizando = false}) async {
    final arquivo = await _baixar(
      _Operacao.salvando,
      (progresso, c) => ref
          .read(offlineProvider)
          .salvar(d, aoProgredir: progresso, cancelamento: c),
    );
    if (arquivo != null && mounted) {
      avisar(
        context,
        atualizando ? 'Arquivo atualizado.' : 'Salvo no aparelho.',
      );
    }
  }

  Future<void> _remover(Documento doc) async {
    await ref.read(offlineProvider).remover(doc.id);
    if (mounted) avisar(context, 'Removido do aparelho.');
  }

  Future<void> _alternarFavorito(Documento doc, bool atual) async {
    try {
      await ref.read(offlineProvider).definirFavorito(doc, !atual);
      ref.read(buscaProvider.notifier).atualizarFavorito(doc.id, !atual);
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  Future<void> _editar(DocumentoDetalhe d) async {
    final resultado = await Navigator.of(context).push<ResultadoDaCatalogacao>(
      MaterialPageRoute(builder: (_) => CatalogarPage.editar(d)),
    );
    if (!mounted || resultado == null) return;
    if (resultado == ResultadoDaCatalogacao.excluido) {
      Navigator.of(context).pop();
    } else {
      ref.invalidate(documentoProvider(widget.documentoId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final carregado = ref.watch(documentoProvider(widget.documentoId));
    final local = ref.watch(_localProvider(widget.documentoId)).value;
    final detalhe = carregado.value?.detalhe;
    final offline = carregado.value?.offline ?? false;
    final doc = detalhe?.documento;
    final favorito = local?.favorito ?? doc?.favorito ?? false;
    final admin = switch (ref.watch(sessaoProvider)) {
      SessaoLogada(:final usuario) => usuario.admin,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documento'),
        actions: [
          if (detalhe != null && admin && !offline)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editar(detalhe),
            ),
          if (doc != null)
            IconButton(
              tooltip: favorito ? 'Remover dos favoritos' : 'Favoritar',
              icon: Icon(favorito ? Icons.star : Icons.star_border),
              onPressed: () => _alternarFavorito(doc, favorito),
            ),
        ],
      ),
      body: carregado.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => Aviso(
          icone: Icons.cloud_off,
          texto: ApiClient.traduzir(erro).mensagem,
          acao: FilledButton.tonal(
            onPressed: () =>
                ref.invalidate(documentoProvider(widget.documentoId)),
            child: const Text('Tentar de novo'),
          ),
        ),
        data: (c) => _conteudo(c.detalhe, c.offline, local),
      ),
    );
  }

  Widget _conteudo(DocumentoDetalhe d, bool offline, DocumentoLocal? local) {
    final doc = d.documento;
    final tema = Theme.of(context);
    final salvo = local?.baixado ?? false;
    final desatualizado =
        salvo &&
        !offline &&
        !doc.indisponivel &&
        local!.versaoBaixada != doc.versaoDoArquivo;
    final ocupado = _operacao != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(doc.titulo, style: tema.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${rotuloDoTipo(doc.tipo)} · ${tamanhoLegivel(doc.tamanhoBytes)}'
          '${salvo ? ' · salvo no aparelho' : ''}',
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (offline)
          const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_off),
              title: Text('Sem conexão. Mostrando a cópia salva no aparelho.'),
            ),
          ),
        if (doc.indisponivel && !salvo)
          const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('O arquivo não está mais disponível no servidor.'),
            ),
          ),
        if (desatualizado)
          Card(
            child: ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Há uma versão mais nova deste arquivo.'),
              trailing: TextButton(
                onPressed: ocupado ? null : () => _salvar(d, atualizando: true),
                child: const Text('Atualizar'),
              ),
            ),
          ),
        if (salvo || !doc.indisponivel) ...[
          const SizedBox(height: 4),
          FilledButton.icon(
            key: const Key('abrir'),
            onPressed: ocupado ? null : () => _abrir(doc),
            icon: const Icon(Icons.open_in_new),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _operacao == _Operacao.abrindo
                    ? 'Baixando… ${(_progresso * 100).round()}%'
                    : 'Abrir',
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (salvo)
            OutlinedButton.icon(
              key: const Key('remover-offline'),
              onPressed: ocupado ? null : () => _remover(doc),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remover do aparelho'),
            )
          else if (!offline)
            OutlinedButton.icon(
              key: const Key('salvar-offline'),
              onPressed: ocupado ? null : () => _salvar(d),
              icon: const Icon(Icons.download_outlined),
              label: Text(
                _operacao == _Operacao.salvando
                    ? 'Salvando… ${(_progresso * 100).round()}%'
                    : 'Salvar para usar offline',
              ),
            ),
          if (ocupado) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progresso == 0 ? null : _progresso),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancelamento?.cancel(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ],
        if (d.veiculos.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Veículos', style: tema.textTheme.titleMedium),
          for (final v in d.veiculos)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.directions_car_outlined),
              title: Text(v.rotulo),
            ),
        ],
        if (d.motores.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Motores', style: tema.textTheme.titleMedium),
          for (final m in d.motores)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: Text(m.rotulo),
            ),
        ],
      ],
    );
  }
}
