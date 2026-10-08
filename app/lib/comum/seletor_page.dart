import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'avisos.dart';

/// Tela de escolha com filtro por texto e a opção de criar um item novo com
/// o que foi digitado, sem sair do fluxo de catalogação. Devolve o item via
/// Navigator.pop.
class SeletorPage<T> extends StatefulWidget {
  const SeletorPage({
    super.key,
    required this.titulo,
    required this.carregar,
    required this.rotulo,
    this.criar,
  });

  final String titulo;
  final Future<List<T>> Function() carregar;
  final String Function(T) rotulo;

  /// Cria um item a partir do texto digitado; null cancela.
  final Future<T?> Function(BuildContext context, String texto)? criar;

  @override
  State<SeletorPage<T>> createState() => _SeletorPageState<T>();
}

class _SeletorPageState<T> extends State<SeletorPage<T>> {
  List<T>? _itens;
  String? _erro;
  var _filtro = '';
  var _criando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final itens = await widget.carregar();
      if (mounted) setState(() => _itens = itens);
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _criar() async {
    setState(() => _criando = true);
    try {
      final novo = await widget.criar!(context, _filtro.trim());
      if (novo != null && mounted) Navigator.of(context).pop(novo);
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = _filtro.trim().toLowerCase();
    final itens = _itens ?? const [];
    final visiveis = [
      for (final i in itens)
        if (widget.rotulo(i).toLowerCase().contains(texto)) i,
    ];
    final existeIgual = itens.any(
      (i) => widget.rotulo(i).toLowerCase() == texto,
    );
    final podeCriar = widget.criar != null && texto.isNotEmpty && !existeIgual;

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('filtro-seletor'),
              autofocus: true,
              onChanged: (v) => setState(() => _filtro = v),
              decoration: const InputDecoration(
                hintText: 'Buscar ou digitar um novo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _erro != null
                ? Aviso(
                    icone: Icons.cloud_off,
                    texto: _erro!,
                    acao: FilledButton.tonal(
                      onPressed: _carregar,
                      child: const Text('Tentar de novo'),
                    ),
                  )
                : _itens == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (podeCriar)
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: Text('Criar "${_filtro.trim()}"'),
                          enabled: !_criando,
                          onTap: _criar,
                        ),
                      for (final i in visiveis)
                        ListTile(
                          title: Text(widget.rotulo(i)),
                          onTap: () => Navigator.of(context).pop(i),
                        ),
                      if (visiveis.isEmpty && !podeCriar)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Nada cadastrado ainda.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
