import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/modelos.dart';
import '../comum/avisos.dart';
import '../comum/seletor_page.dart';
import '../provedores.dart';
import '../util/formatos.dart';
import 'busca.dart';
import 'item_documento.dart';

/// Aba de busca no catálogo do servidor.
class BuscaTab extends ConsumerStatefulWidget {
  const BuscaTab({super.key});

  @override
  ConsumerState<BuscaTab> createState() => _BuscaTabState();
}

class _BuscaTabState extends ConsumerState<BuscaTab> {
  final _texto = TextEditingController();
  final _rolagem = ScrollController();
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(() {
      // Perto do fim da lista: busca a próxima página.
      if (_rolagem.position.extentAfter < 400) {
        ref.read(buscaProvider.notifier).carregarMais();
      }
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  void _aoDigitar(String valor) {
    // Espera o usuário parar de digitar para não buscar a cada letra.
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      ref.read(buscaProvider.notifier).definirTexto(valor);
    });
    setState(() {}); // mostra/esconde o botão de limpar
  }

  void _limpar() {
    _espera?.cancel();
    _texto.clear();
    ref.read(buscaProvider.notifier).definirTexto('');
    setState(() {});
  }

  void _abrirFiltros(Filtros filtros) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PainelDeFiltros(inicial: filtros),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busca = ref.watch(buscaProvider);
    final extras = busca.filtros.extras;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('busca'),
                  controller: _texto,
                  onChanged: _aoDigitar,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Modelo, motor ou título',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _texto.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar',
                            icon: const Icon(Icons.clear),
                            onPressed: _limpar,
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Filtros',
                onPressed: () => _abrirFiltros(busca.filtros),
                icon: Badge(
                  isLabelVisible: extras > 0,
                  label: Text('$extras'),
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
        ),
        _FiltroDeMarca(selecionada: busca.filtros.marcaId),
        Expanded(child: _resultado(busca)),
      ],
    );
  }

  Widget _resultado(BuscaEstado busca) {
    final notifier = ref.read(buscaProvider.notifier);

    if (busca.carregandoDoZero) {
      return const Center(child: CircularProgressIndicator());
    }
    if (busca.erro != null && busca.itens.isEmpty) {
      return Aviso(
        icone: Icons.cloud_off,
        texto: busca.semConexao
            ? '${busca.erro}\nOs documentos salvos continuam na aba Baixados.'
            : busca.erro!,
        acao: FilledButton.tonal(
          onPressed: notifier.recarregar,
          child: const Text('Tentar de novo'),
        ),
      );
    }
    if (busca.itens.isEmpty) {
      return const Aviso(
        icone: Icons.search_off,
        texto: 'Nenhum documento encontrado.',
      );
    }

    // Uma linha extra no fim para o indicador de "carregando mais" ou o erro.
    final temRodape = busca.temMais || busca.erro != null;
    return RefreshIndicator(
      onRefresh: notifier.recarregar,
      child: ListView.separated(
        controller: _rolagem,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: busca.itens.length + (temRodape ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i < busca.itens.length) return ItemDocumento(busca.itens[i]);
          if (busca.erro != null) {
            return ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(busca.erro!),
              trailing: TextButton(
                onPressed: notifier.carregarMais,
                child: const Text('Tentar de novo'),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

class _FiltroDeMarca extends ConsumerWidget {
  const _FiltroDeMarca({required this.selecionada});

  final int? selecionada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marcas = ref.watch(marcasDoFiltroProvider).value ?? const <Marca>[];
    if (marcas.isEmpty) return const SizedBox(height: 8);

    final notifier = ref.read(buscaProvider.notifier);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final m in marcas)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(m.nome),
                selected: m.id == selecionada,
                onSelected: (ligar) =>
                    notifier.definirMarca(ligar ? m.id : null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Filtros menos usados: tipo, modelo (da marca escolhida) e motor.
class _PainelDeFiltros extends ConsumerStatefulWidget {
  const _PainelDeFiltros({required this.inicial});

  final Filtros inicial;

  @override
  ConsumerState<_PainelDeFiltros> createState() => _PainelDeFiltrosState();
}

class _PainelDeFiltrosState extends ConsumerState<_PainelDeFiltros> {
  late Modelo? _modelo = widget.inicial.modelo;
  late Motor? _motor = widget.inicial.motor;
  late String? _tipo = widget.inicial.tipo;

  /// Cada mudança já refaz a busca: o painel pode ser fechado a qualquer hora.
  void _aplicar() {
    ref
        .read(buscaProvider.notifier)
        .definirExtras(modelo: _modelo, motor: _motor, tipo: _tipo);
    setState(() {});
  }

  Future<void> _escolherModelo(int marcaId) async {
    final api = ref.read(apiProvider);
    final modelo = await Navigator.of(context).push<Modelo>(
      MaterialPageRoute(
        builder: (_) => SeletorPage<Modelo>(
          titulo: 'Modelo',
          carregar: () => api.modelos(marcaId),
          rotulo: (m) => m.nome,
        ),
      ),
    );
    if (modelo == null) return;
    _modelo = modelo;
    _aplicar();
  }

  Future<void> _escolherMotor() async {
    final api = ref.read(apiProvider);
    final motor = await Navigator.of(context).push<Motor>(
      MaterialPageRoute(
        builder: (_) => SeletorPage<Motor>(
          titulo: 'Motor',
          carregar: api.motores,
          rotulo: (m) => m.rotulo,
        ),
      ),
    );
    if (motor == null) return;
    _motor = motor;
    _aplicar();
  }

  Widget _limpar(String oQue, VoidCallback aoLimpar) => IconButton(
    tooltip: 'Tirar o filtro de $oQue',
    icon: const Icon(Icons.clear),
    onPressed: () {
      aoLimpar();
      _aplicar();
    },
  );

  @override
  Widget build(BuildContext context) {
    final marcaId = ref.watch(buscaProvider).filtros.marcaId;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final t in tiposDeDocumento.entries)
                  ChoiceChip(
                    label: Text(t.value),
                    selected: _tipo == t.key,
                    onSelected: (ligar) {
                      _tipo = ligar ? t.key : null;
                      _aplicar();
                    },
                  ),
              ],
            ),
          ),
          ListTile(
            key: const Key('filtro-modelo'),
            title: const Text('Modelo'),
            subtitle: Text(
              _modelo?.nome ??
                  (marcaId == null ? 'Escolha uma marca antes' : 'Todos'),
            ),
            enabled: marcaId != null,
            trailing: _modelo == null
                ? const Icon(Icons.chevron_right)
                : _limpar('modelo', () => _modelo = null),
            onTap: marcaId == null ? null : () => _escolherModelo(marcaId),
          ),
          ListTile(
            key: const Key('filtro-motor'),
            title: const Text('Motor'),
            subtitle: Text(_motor?.rotulo ?? 'Todos'),
            trailing: _motor == null
                ? const Icon(Icons.chevron_right)
                : _limpar('motor', () => _motor = null),
            onTap: _escolherMotor,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
