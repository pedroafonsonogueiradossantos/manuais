import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../comum/avisos.dart';
import '../documentos/item_documento.dart';
import '../provedores.dart';
import '../util/formatos.dart';
import 'banco_local.dart';

final _favoritosProvider = StreamProvider<List<DocumentoLocal>>(
  (ref) => ref.watch(bancoLocalProvider).observarFavoritos(),
);

final _baixadosProvider = StreamProvider.family<List<DocumentoLocal>, String>(
  (ref, q) => ref.watch(bancoLocalProvider).observarBaixados(q: q),
);

/// Favoritos a partir da cópia local: a lista abre mesmo sem internet.
class FavoritosTab extends ConsumerWidget {
  const FavoritosTab({super.key});

  Future<void> _sincronizar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(offlineProvider).sincronizarFavoritos();
    } on ApiErro catch (e) {
      if (context.mounted) avisar(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritos = ref.watch(_favoritosProvider).value;
    if (favoritos == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _sincronizar(context, ref),
      child: favoritos.isEmpty
          // Rolável mesmo vazio, para o gesto de atualizar funcionar.
          ? LayoutBuilder(
              builder: (_, limites) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: limites.maxHeight,
                  child: const Aviso(
                    icone: Icons.star_border,
                    texto: 'Nenhum favorito ainda.\nToque na estrela de um documento para guardá-lo aqui.',
                  ),
                ),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: favoritos.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => ItemDocumento(favoritos[i].documento),
            ),
    );
  }
}

/// Documentos salvos no aparelho, com busca que funciona sem internet.
class BaixadosTab extends ConsumerStatefulWidget {
  const BaixadosTab({super.key});

  @override
  ConsumerState<BaixadosTab> createState() => _BaixadosTabState();
}

class _BaixadosTabState extends ConsumerState<BaixadosTab> {
  var _q = '';

  Future<void> _remover(DocumentoLocal d) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do aparelho?'),
        content: Text(
          '"${d.titulo}" continuará disponível para baixar de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou == true) await ref.read(offlineProvider).remover(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final baixados = ref.watch(_baixadosProvider(_q)).value;
    final total =
        baixados?.fold<int>(0, (soma, d) => soma + d.tamanhoBytes) ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            key: const Key('busca-baixados'),
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Buscar nos baixados',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (baixados != null && baixados.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${baixados.length} ${baixados.length == 1 ? 'documento' : 'documentos'}'
                ' · ${tamanhoLegivel(total)}',
              ),
            ),
          ),
        Expanded(
          child: baixados == null
              ? const Center(child: CircularProgressIndicator())
              : baixados.isEmpty
              ? Aviso(
                  icone: Icons.download_outlined,
                  texto: _q.trim().isEmpty
                      ? 'Nada salvo no aparelho.\nAbra um documento e toque em "Salvar para usar offline".'
                      : 'Nenhum baixado com esse texto.',
                )
              : ListView.separated(
                  itemCount: baixados.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => ItemDocumento(
                    baixados[i].documento,
                    acao: IconButton(
                      tooltip: 'Remover do aparelho',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remover(baixados[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
