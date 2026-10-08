import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:photo_view/photo_view.dart';

import '../api/modelos.dart';

/// Mostra um arquivo que já está no disco: PDF ou imagem com zoom.
class VisualizadorPage extends StatelessWidget {
  const VisualizadorPage({
    super.key,
    required this.titulo,
    required this.ehImagem,
    required this.arquivo,
  });

  VisualizadorPage.doDocumento(Documento doc, this.arquivo, {super.key})
    : titulo = doc.titulo,
      ehImagem = doc.ehImagem;

  final String titulo;
  final bool ehImagem;
  final File arquivo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: ehImagem
          ? PhotoView(
              imageProvider: FileImage(arquivo),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 5,
              backgroundDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              errorBuilder: (_, _, _) => const _NaoAbriu(),
            )
          : PdfViewer.file(
              arquivo.path,
              params: PdfViewerParams(
                errorBannerBuilder: (_, _, _, _) => const _NaoAbriu(),
              ),
            ),
    );
  }
}

class _NaoAbriu extends StatelessWidget {
  const _NaoAbriu();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Não foi possível abrir este arquivo.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
