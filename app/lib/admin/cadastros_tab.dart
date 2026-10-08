import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../comum/avisos.dart';
import '../documentos/busca.dart';
import '../provedores.dart';

/// Manutenção de marcas, modelos, veículos e motores: renomear e excluir.
/// (Criar acontece durante a catalogação.)
class CadastrosTab extends ConsumerStatefulWidget {
  const CadastrosTab({super.key});

  @override
  ConsumerState<CadastrosTab> createState() => _CadastrosTabState();
}

class _CadastrosTabState extends ConsumerState<CadastrosTab> {
  var _motores = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Marcas')),
              ButtonSegment(value: true, label: Text('Motores')),
            ],
            selected: {_motores},
            onSelectionChanged: (s) => setState(() => _motores = s.first),
          ),
        ),
        Expanded(
          child: _motores
              ? ListaDeCadastro<Motor>(
                  key: const ValueKey('motores'),
                  vazio: 'Nenhum motor cadastrado.',
                  carregar: api.motores,
                  rotulo: (m) => m.rotulo,
                  editar: (context, m) async {
                    final dados = await _pedirTextos(context, 'Editar motor', [
                      ('Código', m.codigo),
                      ('Descrição', m.descricao),
                    ], obrigatorios: 1);
                    if (dados == null) return false;
                    await api.atualizarMotor(m.id, dados[0], dados[1]);
                    return true;
                  },
                  excluir: (m) => api.excluirMotor(m.id),
                )
              : ListaDeCadastro<Marca>(
                  key: const ValueKey('marcas'),
                  vazio: 'Nenhuma marca cadastrada.',
                  carregar: api.marcas,
                  rotulo: (m) => m.nome,
                  editar: (context, m) async {
                    final dados = await _pedirTextos(
                      context,
                      'Renomear marca',
                      [('Nome', m.nome)],
                    );
                    if (dados == null) return false;
                    await api.renomearMarca(m.id, dados[0]);
                    return true;
                  },
                  excluir: (m) => api.excluirMarca(m.id),
                  aoTocar: (context, m) => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _ModelosPage(marca: m)),
                  ),
                  // Nome ou existência da marca mudam o filtro da busca.
                  aoMudar: () => ref.invalidate(marcasDoFiltroProvider),
                ),
        ),
      ],
    );
  }
}

class _ModelosPage extends ConsumerWidget {
  const _ModelosPage({required this.marca});

  final Marca marca;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Modelos de ${marca.nome}')),
      body: ListaDeCadastro<Modelo>(
        vazio: 'Nenhum modelo nesta marca.',
        carregar: () => api.modelos(marca.id),
        rotulo: (m) => m.nome,
        editar: (context, m) async {
          final dados = await _pedirTextos(context, 'Renomear modelo', [
            ('Nome', m.nome),
          ]);
          if (dados == null) return false;
          await api.renomearModelo(m, dados[0]);
          return true;
        },
        excluir: (m) => api.excluirModelo(m.id),
        aoTocar: (context, m) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text('Veículos · ${marca.nome} ${m.nome}')),
              body: ListaDeCadastro<Veiculo>(
                vazio: 'Nenhum veículo neste modelo.',
                carregar: () => api.veiculos(m.id),
                rotulo: (v) => v.rotulo,
                excluir: (v) => api.excluirVeiculo(v.id),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo com um ou mais campos de texto; devolve os valores (sem espaços
/// nas pontas) ou null se cancelado. Os [obrigatorios] primeiros não podem
/// ficar vazios.
Future<List<String>?> _pedirTextos(
  BuildContext context,
  String titulo,
  List<(String rotulo, String valor)> campos, {
  int? obrigatorios,
}) {
  final controles = [for (final c in campos) TextEditingController(text: c.$2)];
  return showDialog<List<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < campos.length; i++)
            TextField(
              key: Key('campo-$i'),
              controller: controles[i],
              autofocus: i == 0,
              decoration: InputDecoration(labelText: campos[i].$1),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final valores = [for (final c in controles) c.text.trim()];
            final exigidos = obrigatorios ?? valores.length;
            if (valores.take(exigidos).any((v) => v.isEmpty)) return;
            Navigator.pop(context, valores);
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// Lista de um cadastro com as ações de editar e excluir em cada linha.
class ListaDeCadastro<T> extends ConsumerStatefulWidget {
  const ListaDeCadastro({
    super.key,
    required this.vazio,
    required this.carregar,
    required this.rotulo,
    required this.excluir,
    this.editar,
    this.aoTocar,
    this.aoMudar,
  });

  final String vazio;
  final Future<List<T>> Function() carregar;
  final String Function(T) rotulo;
  final Future<void> Function(T) excluir;

  /// Devolve true se gravou alguma mudança.
  final Future<bool> Function(BuildContext, T)? editar;
  final Future<void> Function(BuildContext, T)? aoTocar;
  final VoidCallback? aoMudar;

  @override
  ConsumerState<ListaDeCadastro<T>> createState() => _ListaDeCadastroState<T>();
}

class _ListaDeCadastroState<T> extends ConsumerState<ListaDeCadastro<T>> {
  List<T>? _itens;
  String? _erro;

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

  /// Depois de qualquer gravação: relê a lista e avisa as telas que mostram
  /// esses nomes (a busca guarda títulos e filtros).
  Future<void> _mudou() async {
    widget.aoMudar?.call();
    ref.read(buscaProvider.notifier).recarregar();
    await _carregar();
  }

  Future<void> _editar(T item) async {
    try {
      if (await widget.editar!(context, item)) await _mudou();
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  Future<void> _excluir(T item) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir "${widget.rotulo(item)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await widget.excluir(item);
      await _mudou();
    } on ApiErro catch (e) {
      // "Em uso" é o caso comum: o servidor explica na mensagem.
      if (mounted) avisar(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_erro != null) {
      return Aviso(
        icone: Icons.cloud_off,
        texto: _erro!,
        acao: FilledButton.tonal(
          onPressed: _carregar,
          child: const Text('Tentar de novo'),
        ),
      );
    }
    final itens = _itens;
    if (itens == null) return const Center(child: CircularProgressIndicator());
    if (itens.isEmpty) {
      return Aviso(icone: Icons.inbox_outlined, texto: widget.vazio);
    }

    return ListView.separated(
      itemCount: itens.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = itens[i];
        return ListTile(
          title: Text(widget.rotulo(item)),
          onTap: widget.aoTocar == null
              ? null
              : () async {
                  await widget.aoTocar!(context, item);
                  // Na volta, algo de dentro pode ter mudado.
                  if (mounted) await _carregar();
                },
          trailing: PopupMenuButton<String>(
            tooltip: 'Opções de ${widget.rotulo(item)}',
            onSelected: (opcao) =>
                opcao == 'editar' ? _editar(item) : _excluir(item),
            itemBuilder: (_) => [
              if (widget.editar != null)
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
              const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
            ],
          ),
        );
      },
    );
  }
}
