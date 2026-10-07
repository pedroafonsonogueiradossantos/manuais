import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/modelos.dart';
import '../auth/sessao.dart';
import '../provedores.dart';
import '../util/formatos.dart';
import 'busca.dart';
import 'detalhe_page.dart';

class BuscaPage extends ConsumerStatefulWidget {
  const BuscaPage({super.key});

  @override
  ConsumerState<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends ConsumerState<BuscaPage> {
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

  @override
  Widget build(BuildContext context) {
    final busca = ref.watch(buscaProvider);
    final usuario = switch (ref.watch(sessaoProvider)) {
      SessaoLogada(:final usuario) => usuario,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuais'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Conta',
            icon: const Icon(Icons.account_circle),
            onSelected: (_) => ref.read(sessaoProvider.notifier).sair(),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(usuario == null ? '' : '${usuario.nome}\n${usuario.email}'),
              ),
              const PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          _FiltroDeMarca(selecionada: busca.marcaId),
          Expanded(child: _resultado(busca)),
        ],
      ),
    );
  }

  Widget _resultado(BuscaEstado busca) {
    final notifier = ref.read(buscaProvider.notifier);

    if (busca.carregandoDoZero) {
      return const Center(child: CircularProgressIndicator());
    }
    if (busca.erro != null && busca.itens.isEmpty) {
      return _Aviso(
        icone: Icons.cloud_off,
        texto: busca.erro!,
        acao: FilledButton.tonal(
          onPressed: notifier.recarregar,
          child: const Text('Tentar de novo'),
        ),
      );
    }
    if (busca.itens.isEmpty) {
      return const _Aviso(
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
          if (i < busca.itens.length) return _ItemDocumento(busca.itens[i]);
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
    final marcas = ref.watch(marcasProvider).value ?? const <Marca>[];
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
                onSelected: (ligar) => notifier.definirMarca(ligar ? m.id : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemDocumento extends StatelessWidget {
  const _ItemDocumento(this.doc);

  final Documento doc;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(doc.ehImagem ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
      title: Text(doc.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${rotuloDoTipo(doc.tipo)} · ${tamanhoLegivel(doc.tamanhoBytes)}'
        '${doc.indisponivel ? ' · indisponível' : ''}',
      ),
      trailing: doc.favorito ? const Icon(Icons.star, size: 20) : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetalhePage(documentoId: doc.id)),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto, this.acao});

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
