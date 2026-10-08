import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../arquivos/arquivo_cache.dart';
import '../arquivos/visualizador_page.dart';
import '../documentos/busca.dart';
import '../provedores.dart';
import '../util/formatos.dart';
import '../comum/avisos.dart';
import 'veiculo_page.dart';

/// Veículos e motores do último documento catalogado: arquivos vizinhos na
/// fila costumam ser do mesmo carro.
class UltimaCatalogacao {
  const UltimaCatalogacao({this.veiculos = const [], this.motores = const []});

  final List<Veiculo> veiculos;
  final List<Motor> motores;

  bool get vazia => veiculos.isEmpty && motores.isEmpty;
}

class _UltimaCatalogacaoNotifier extends Notifier<UltimaCatalogacao> {
  @override
  UltimaCatalogacao build() => const UltimaCatalogacao();

  void definir(UltimaCatalogacao valor) => state = valor;
}

final ultimaCatalogacaoProvider =
    NotifierProvider<_UltimaCatalogacaoNotifier, UltimaCatalogacao>(
      _UltimaCatalogacaoNotifier.new,
    );

enum ResultadoDaCatalogacao {
  /// Catalogado, ignorado ou devolvido: saiu da lista em que estava.
  saiuDaFila,
  salvo,
  excluido,
}

/// Formulário de catalogação: cria um documento a partir de um arquivo da
/// fila ou edita um documento existente. Devolve [ResultadoDaCatalogacao]
/// via pop quando algo foi gravado.
class CatalogarPage extends ConsumerStatefulWidget {
  const CatalogarPage({super.key, required ArquivoPendente this.arquivo})
    : documento = null;

  const CatalogarPage.editar(DocumentoDetalhe this.documento, {super.key})
    : arquivo = null;

  /// Arquivo da fila (modo criar).
  final ArquivoPendente? arquivo;

  /// Documento existente (modo editar).
  final DocumentoDetalhe? documento;

  @override
  ConsumerState<CatalogarPage> createState() => _CatalogarPageState();
}

class _CatalogarPageState extends ConsumerState<CatalogarPage> {
  late final _titulo = TextEditingController(
    text: widget.documento?.documento.titulo ?? widget.arquivo!.tituloSugerido,
  );
  late var _tipo =
      widget.documento?.documento.tipo ??
      (widget.arquivo!.ehImagem ? 'foto' : 'manual_servico');
  late var _veiculos = widget.documento?.veiculos ?? <Veiculo>[];
  late var _motores = widget.documento?.motores ?? <Motor>[];
  var _ocupado = false;
  double? _progresso;
  CancelToken? _cancelamento;

  @override
  void dispose() {
    _cancelamento?.cancel();
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _visualizar() async {
    if (_progresso != null) return;
    final cancelamento = _cancelamento = CancelToken();
    setState(() => _progresso = 0);
    try {
      final arquivo = await ref
          .read(arquivoCacheProvider)
          .obterRemoto(
            ArquivoRemoto.doPendente(widget.arquivo!),
            cancelamento: cancelamento,
            aoProgredir: (recebido, total) {
              if (mounted && total > 0) {
                setState(() => _progresso = recebido / total);
              }
            },
          );
      if (!mounted) return;
      setState(() => _progresso = null);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisualizadorPage(
            titulo: widget.arquivo!.nome,
            ehImagem: widget.arquivo!.ehImagem,
            arquivo: arquivo,
          ),
        ),
      );
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _progresso = null);
      if (!cancelamento.isCancelled) avisar(context, e.mensagem);
    }
  }

  Future<void> _adicionarVeiculo() async {
    final v = await Navigator.of(context)
        .push<Veiculo>(MaterialPageRoute(builder: (_) => const VeiculoPage()));
    if (v == null || !mounted || _veiculos.any((x) => x.id == v.id)) return;
    setState(() => _veiculos = [..._veiculos, v]);
  }

  Future<void> _adicionarMotor() async {
    final m = await escolherMotor(context, ref);
    if (m == null || !mounted || _motores.any((x) => x.id == m.id)) return;
    setState(() => _motores = [..._motores, m]);
  }

  /// Executa uma gravação e fecha a tela devolvendo o resultado.
  Future<void> _concluir(
    Future<void> Function() acao,
    String mensagem, [
    ResultadoDaCatalogacao resultado = ResultadoDaCatalogacao.saiuDaFila,
  ]) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (!mounted) return;
      avisar(context, mensagem);
      Navigator.of(context).pop(resultado);
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      avisar(context, e.mensagem);
    }
  }

  Future<void> _salvar() async {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) {
      avisar(context, 'Informe o título.');
      return;
    }
    final api = ref.read(apiProvider);
    final veiculoIds = [for (final v in _veiculos) v.id];
    final motorIds = [for (final m in _motores) m.id];
    final editando = widget.documento;

    if (editando != null) {
      await _concluir(
        () async {
          await api.atualizarDocumento(
            editando.documento.id,
            titulo: titulo,
            tipo: _tipo,
            veiculoIds: veiculoIds,
            motorIds: motorIds,
          );
          ref.read(buscaProvider.notifier).recarregar();
        },
        'Documento atualizado.',
        ResultadoDaCatalogacao.salvo,
      );
      return;
    }

    await _concluir(() async {
      await api.criarDocumento(
        titulo: titulo,
        tipo: _tipo,
        storageFileId: widget.arquivo!.storageFileId,
        veiculoIds: veiculoIds,
        motorIds: motorIds,
      );
      ref
          .read(ultimaCatalogacaoProvider.notifier)
          .definir(UltimaCatalogacao(veiculos: _veiculos, motores: _motores));
      // O documento novo precisa aparecer na busca principal.
      ref.read(buscaProvider.notifier).recarregar();
    }, 'Documento catalogado.');
  }

  Future<void> _alternarIgnorado() {
    final arquivo = widget.arquivo!;
    final ignorar = !arquivo.ignorado;
    return _concluir(
      () =>
          ref.read(apiProvider).definirIgnorado(arquivo.storageFileId, ignorar),
      ignorar ? 'Arquivo ignorado.' : 'Arquivo devolvido à fila.',
    );
  }

  Future<void> _excluir() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir documento?'),
        content: const Text(
          'O arquivo continua no Drive e volta para a fila de pendentes. '
          'Os favoritos deste documento são perdidos.',
        ),
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
    final id = widget.documento!.documento.id;
    await _concluir(
      () async {
        await ref.read(apiProvider).excluirDocumento(id);
        // Não deixa para trás um arquivo salvo de um documento que não existe mais.
        await ref.read(offlineProvider).remover(id);
        ref.read(buscaProvider.notifier).recarregar();
      },
      'Documento excluído.',
      ResultadoDaCatalogacao.excluido,
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.arquivo;
    final editando = a == null;
    final tema = Theme.of(context);
    final ultima = ref.watch(ultimaCatalogacaoProvider);
    final baixando = _progresso != null;
    final semAssociacao = _veiculos.isEmpty && _motores.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar documento' : 'Catalogar'),
        actions: [
          if (a == null)
            TextButton(
              onPressed: _ocupado ? null : _excluir,
              child: const Text('Excluir'),
            )
          else
            TextButton(
              onPressed: _ocupado ? null : _alternarIgnorado,
              child: Text(a.ignorado ? 'Devolver à fila' : 'Ignorar'),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('salvar'),
            onPressed: _ocupado ? null : _salvar,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Salvar'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (a != null)
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  a.ehImagem
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                ),
                title: Text(a.nome),
                subtitle: Text(
                  [
                    if (a.caminho.isNotEmpty) a.caminho,
                    tamanhoLegivel(a.tamanhoBytes),
                  ].join(' · '),
                ),
                trailing: baixando
                    ? IconButton(
                        tooltip: 'Cancelar',
                        icon: const Icon(Icons.close),
                        onPressed: () => _cancelamento?.cancel(),
                      )
                    : IconButton(
                        tooltip: 'Visualizar',
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: _visualizar,
                      ),
              ),
            ),
          if (baixando)
            LinearProgressIndicator(value: _progresso == 0 ? null : _progresso),
          if (a != null) const SizedBox(height: 20),
          TextField(
            key: const Key('titulo'),
            controller: _titulo,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final t in tiposDeDocumento.entries)
                DropdownMenuItem(value: t.key, child: Text(t.value)),
            ],
            onChanged: (v) => setState(() => _tipo = v!),
          ),
          if (!editando && semAssociacao && !ultima.vazia) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('Usar os do último documento'),
              onPressed: () => setState(() {
                _veiculos = ultima.veiculos;
                _motores = ultima.motores;
              }),
            ),
          ],
          const SizedBox(height: 24),
          Text('Veículos', style: tema.textTheme.titleMedium),
          for (final v in _veiculos)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.directions_car_outlined),
              title: Text(v.rotulo),
              trailing: IconButton(
                tooltip: 'Remover',
                icon: const Icon(Icons.close),
                onPressed: () => setState(
                  () =>
                      _veiculos = _veiculos.where((x) => x.id != v.id).toList(),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar veículo'),
              onPressed: _adicionarVeiculo,
            ),
          ),
          const SizedBox(height: 16),
          Text('Motores', style: tema.textTheme.titleMedium),
          Text(
            'Para documentos que valem para todo carro com o motor.',
            style: tema.textTheme.bodySmall,
          ),
          for (final m in _motores)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: Text(m.rotulo),
              trailing: IconButton(
                tooltip: 'Remover',
                icon: const Icon(Icons.close),
                onPressed: () => setState(
                  () => _motores = _motores.where((x) => x.id != m.id).toList(),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar motor'),
              onPressed: _adicionarMotor,
            ),
          ),
        ],
      ),
    );
  }
}
