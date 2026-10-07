import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../arquivos/visualizador_page.dart';
import '../provedores.dart';
import '../util/formatos.dart';
import 'busca.dart';

final documentoProvider = FutureProvider.autoDispose.family<DocumentoDetalhe, int>(
  (ref, id) => ref.watch(apiProvider).documento(id),
);

class DetalhePage extends ConsumerStatefulWidget {
  const DetalhePage({super.key, required this.documentoId});

  final int documentoId;

  @override
  ConsumerState<DetalhePage> createState() => _DetalhePageState();
}

class _DetalhePageState extends ConsumerState<DetalhePage> {
  /// Fração baixada (0 a 1) enquanto o arquivo é aberto; null = parado.
  double? _progresso;
  CancelToken? _cancelamento;

  /// Favorito já alterado nesta tela, antes de o servidor confirmar.
  bool? _favorito;

  @override
  void dispose() {
    _cancelamento?.cancel();
    super.dispose();
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrir(Documento doc) async {
    if (_progresso != null) return;
    final cancelamento = _cancelamento = CancelToken();
    setState(() => _progresso = 0);
    try {
      final arquivo = await ref
          .read(arquivoCacheProvider)
          .obter(
            doc,
            cancelamento: cancelamento,
            aoProgredir: (recebido, total) {
              if (mounted && total > 0) setState(() => _progresso = recebido / total);
            },
          );
      if (!mounted) return;
      setState(() => _progresso = null);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisualizadorPage(documento: doc, arquivo: arquivo),
        ),
      );
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _progresso = null);
      if (!cancelamento.isCancelled) _avisar(e.mensagem);
    }
  }

  Future<void> _alternarFavorito(Documento doc) async {
    final novo = !(_favorito ?? doc.favorito);
    setState(() => _favorito = novo);
    try {
      await ref.read(apiProvider).definirFavorito(doc.id, novo);
      ref.read(buscaProvider.notifier).atualizarFavorito(doc.id, novo);
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _favorito = !novo);
      _avisar(e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalhe = ref.watch(documentoProvider(widget.documentoId));
    final doc = detalhe.value?.documento;
    final favorito = _favorito ?? doc?.favorito ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documento'),
        actions: [
          if (doc != null)
            IconButton(
              tooltip: favorito ? 'Remover dos favoritos' : 'Favoritar',
              icon: Icon(favorito ? Icons.star : Icons.star_border),
              onPressed: () => _alternarFavorito(doc),
            ),
        ],
      ),
      body: detalhe.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ApiClient.traduzir(erro).mensagem, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(documentoProvider(widget.documentoId)),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
        data: _conteudo,
      ),
    );
  }

  Widget _conteudo(DocumentoDetalhe d) {
    final doc = d.documento;
    final tema = Theme.of(context);
    final baixando = _progresso != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(doc.titulo, style: tema.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${rotuloDoTipo(doc.tipo)} · ${tamanhoLegivel(doc.tamanhoBytes)}',
          style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        if (doc.indisponivel)
          const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('O arquivo não está mais disponível no servidor.'),
            ),
          )
        else ...[
          FilledButton.icon(
            key: const Key('abrir'),
            onPressed: baixando ? null : () => _abrir(doc),
            icon: const Icon(Icons.open_in_new),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(baixando ? 'Baixando… ${(_progresso! * 100).round()}%' : 'Abrir'),
            ),
          ),
          if (baixando) ...[
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
