import 'package:flutter/material.dart';

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    // remove (e não hide): sem animação pendente se a tela fechar em seguida.
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Mensagem centralizada com ação opcional (lista vazia, erro de carga).
class Aviso extends StatelessWidget {
  const Aviso({super.key, required this.icone, required this.texto, this.acao});

  final IconData icone;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center),
            if (acao != null) ...[const SizedBox(height: 16), acao!],
          ],
        ),
      ),
    );
  }
}
