import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/modelos.dart';
import '../offline/banco_local.dart';
import '../provedores.dart';
import '../util/formatos.dart';
import 'detalhe_page.dart';

/// Linha de documento usada nas três listas (busca, favoritos, baixados).
class ItemDocumento extends ConsumerWidget {
  const ItemDocumento(this.doc, {super.key, this.acao});

  final Documento doc;

  /// Botão extra à direita (ex.: remover da lista de baixados).
  final Widget? acao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(locaisProvider).value?[doc.id];
    final favorito = local?.favorito ?? doc.favorito;
    final salvo = local?.baixado ?? false;

    return ListTile(
      leading: Icon(
        doc.ehImagem ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
      ),
      title: Text(doc.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${rotuloDoTipo(doc.tipo)} · ${tamanhoLegivel(doc.tamanhoBytes)}'
        '${doc.indisponivel ? ' · indisponível' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (salvo)
            const Tooltip(
              message: 'Salvo no aparelho',
              child: Icon(Icons.download_done, size: 20),
            ),
          if (favorito)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.star, size: 20),
            ),
          ?acao,
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetalhePage(documentoId: doc.id)),
      ),
    );
  }
}
