import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../provedores.dart';
import '../util/formatos.dart';
import '../comum/avisos.dart';
import 'catalogar_page.dart';

/// Fila de arquivos do Drive que ainda não foram catalogados.
class PendentesTab extends ConsumerStatefulWidget {
  const PendentesTab({super.key});

  @override
  ConsumerState<PendentesTab> createState() => _PendentesTabState();
}

class _PendentesTabState extends ConsumerState<PendentesTab>
    with AutomaticKeepAliveClientMixin {
  final _rolagem = ScrollController();
  Timer? _espera;

  var _itens = <ArquivoPendente>[];
  var _total = 0;
  var _pagina = 0;
  var _temMais = false;
  var _carregando = true;
  var _sincronizando = false;
  var _ignorados = false;
  var _q = '';
  String? _erro;

  /// Descarta respostas de cargas que foram substituídas por outra.
  var _geracao = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(() {
      if (_rolagem.position.extentAfter < 400 && _temMais && !_carregando) {
        _carregar();
      }
    });
    _carregar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _recarregar() {
    _itens = [];
    _pagina = 0;
    return _carregar();
  }

  Future<void> _carregar() async {
    final geracao = ++_geracao;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final p = await ref
          .read(apiProvider)
          .pendentes(q: _q, ignorados: _ignorados, pagina: _pagina + 1);
      if (!mounted || geracao != _geracao) return;
      setState(() {
        _itens = [..._itens, ...p.itens];
        _total = p.total;
        _pagina = p.pagina;
        _temMais = p.temMais;
        _carregando = false;
      });
    } on ApiErro catch (e) {
      if (!mounted || geracao != _geracao) return;
      setState(() {
        _carregando = false;
        _erro = e.mensagem;
      });
    }
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    try {
      final r = await ref.read(apiProvider).sincronizar();
      if (!mounted) return;
      avisar(
        context,
        'Drive sincronizado: ${r.arquivos} arquivos, ${r.removidos} removidos.',
      );
      await _recarregar();
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  void _aoDigitar(String valor) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      _q = valor;
      _recarregar();
    });
  }

  Future<void> _abrir(ArquivoPendente arquivo) async {
    final resultado = await Navigator.of(context).push<ResultadoDaCatalogacao>(
      MaterialPageRoute(builder: (_) => CatalogarPage(arquivo: arquivo)),
    );
    if (resultado == ResultadoDaCatalogacao.saiuDaFila && mounted) {
      setState(() {
        _itens = _itens
            .where((a) => a.storageFileId != arquivo.storageFileId)
            .toList();
        _total--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('busca-pendentes'),
                  onChanged: _aoDigitar,
                  decoration: const InputDecoration(
                    hintText: 'Nome do arquivo ou pasta',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sincronizar com o Drive',
                onPressed: _sincronizando ? null : _sincronizar,
                icon: _sincronizando
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _carregando && _pagina == 0
                      ? ''
                      : '$_total ${_ignorados ? 'ignorados' : 'a catalogar'}',
                ),
              ),
              FilterChip(
                label: const Text('Ignorados'),
                selected: _ignorados,
                onSelected: (v) {
                  _ignorados = v;
                  _recarregar();
                },
              ),
            ],
          ),
        ),
        Expanded(child: _lista()),
      ],
    );
  }

  Widget _lista() {
    if (_carregando && _itens.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null && _itens.isEmpty) {
      return Aviso(
        icone: Icons.cloud_off,
        texto: _erro!,
        acao: FilledButton.tonal(
          onPressed: _recarregar,
          child: const Text('Tentar de novo'),
        ),
      );
    }
    if (_itens.isEmpty) {
      return Aviso(
        icone: Icons.inbox_outlined,
        texto: _ignorados ? 'Nenhum arquivo ignorado.' : 'Nada a catalogar. Toque em sincronizar para reler a pasta do Drive.',
      );
    }
    return RefreshIndicator(
      onRefresh: _recarregar,
      child: ListView.separated(
        controller: _rolagem,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _itens.length + (_temMais ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i >= _itens.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final a = _itens[i];
          return ListTile(
            leading: Icon(
              a.ehImagem ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
            ),
            title: Text(a.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (a.caminho.isNotEmpty) a.caminho,
                tamanhoLegivel(a.tamanhoBytes),
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrir(a),
          );
        },
      ),
    );
  }
}
