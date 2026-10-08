import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../provedores.dart';
import '../comum/avisos.dart';
import '../comum/seletor_page.dart';

/// Abre a escolha de motor, permitindo cadastrar um novo (código + descrição).
Future<Motor?> escolherMotor(BuildContext context, WidgetRef ref) {
  final api = ref.read(apiProvider);
  return Navigator.of(context).push<Motor>(
    MaterialPageRoute(
      builder: (_) => SeletorPage<Motor>(
        titulo: 'Motor',
        carregar: api.motores,
        rotulo: (m) => m.rotulo,
        criar: (context, texto) async {
          final dados = await showDialog<(String, String)>(
            context: context,
            builder: (_) => _NovoMotorDialog(codigoInicial: texto),
          );
          if (dados == null) return null;
          return api.criarMotor(dados.$1, dados.$2);
        },
      ),
    ),
  );
}

class _NovoMotorDialog extends StatefulWidget {
  const _NovoMotorDialog({required this.codigoInicial});

  final String codigoInicial;

  @override
  State<_NovoMotorDialog> createState() => _NovoMotorDialogState();
}

class _NovoMotorDialogState extends State<_NovoMotorDialog> {
  late final _codigo = TextEditingController(text: widget.codigoInicial);
  final _descricao = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    _descricao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo motor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('motor-codigo'),
            controller: _codigo,
            decoration: const InputDecoration(labelText: 'Código (ex.: EA111)'),
          ),
          TextField(
            key: const Key('motor-descricao'),
            controller: _descricao,
            decoration: const InputDecoration(
              labelText: 'Descrição (ex.: 1.6 8v)',
            ),
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
            final codigo = _codigo.text.trim();
            if (codigo.isEmpty) return;
            Navigator.pop(context, (codigo, _descricao.text.trim()));
          },
          child: const Text('Criar'),
        ),
      ],
    );
  }
}

/// Monta um veículo (marca, modelo, motor e anos opcionais) e devolve-o já
/// gravado no servidor. Marca, modelo e motor podem ser criados na hora.
class VeiculoPage extends ConsumerStatefulWidget {
  const VeiculoPage({super.key});

  @override
  ConsumerState<VeiculoPage> createState() => _VeiculoPageState();
}

class _VeiculoPageState extends ConsumerState<VeiculoPage> {
  final _anoInicio = TextEditingController();
  final _anoFim = TextEditingController();
  Marca? _marca;
  Modelo? _modelo;
  Motor? _motor;
  var _salvando = false;

  @override
  void dispose() {
    _anoInicio.dispose();
    _anoFim.dispose();
    super.dispose();
  }

  Future<void> _escolherMarca() async {
    final api = ref.read(apiProvider);
    final marca = await Navigator.of(context).push<Marca>(
      MaterialPageRoute(
        builder: (_) => SeletorPage<Marca>(
          titulo: 'Marca',
          carregar: api.marcas,
          rotulo: (m) => m.nome,
          criar: (_, texto) => api.criarMarca(texto),
        ),
      ),
    );
    if (marca == null || !mounted) return;
    setState(() {
      if (marca.id != _marca?.id) _modelo = null;
      _marca = marca;
    });
    // Marca nova muda o filtro da busca principal.
    ref.invalidate(marcasDoFiltroProvider);
  }

  Future<void> _escolherModelo() async {
    final api = ref.read(apiProvider);
    final marca = _marca!;
    final modelo = await Navigator.of(context).push<Modelo>(
      MaterialPageRoute(
        builder: (_) => SeletorPage<Modelo>(
          titulo: 'Modelo de ${marca.nome}',
          carregar: () => api.modelos(marca.id),
          rotulo: (m) => m.nome,
          criar: (_, texto) => api.criarModelo(marca.id, texto),
        ),
      ),
    );
    if (modelo != null && mounted) setState(() => _modelo = modelo);
  }

  Future<void> _escolherMotor() async {
    final motor = await escolherMotor(context, ref);
    if (motor != null && mounted) setState(() => _motor = motor);
  }

  Future<void> _adicionar() async {
    final inicio = int.tryParse(_anoInicio.text);
    final fim = int.tryParse(_anoFim.text);
    if (inicio != null && fim != null && fim < inicio) {
      avisar(context, 'O ano final não pode ser menor que o inicial.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final id = await ref
          .read(apiProvider)
          .criarVeiculo(
            modeloId: _modelo!.id,
            motorId: _motor?.id,
            anoInicio: inicio,
            anoFim: fim,
          );
      if (!mounted) return;
      Navigator.of(context).pop(
        Veiculo(
          id: id,
          marcaNome: _marca!.nome,
          modeloNome: _modelo!.nome,
          motorCodigo: _motor?.codigo,
          motorDescricao: _motor?.descricao,
          anoInicio: inicio,
          anoFim: fim,
        ),
      );
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      avisar(context, e.mensagem);
    }
  }

  Widget _campoAno(String rotulo, TextEditingController c, Key chave) {
    return Expanded(
      child: TextField(
        key: chave,
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          labelText: rotulo,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar veículo')),
      body: ListView(
        children: [
          ListTile(
            key: const Key('campo-marca'),
            title: const Text('Marca'),
            subtitle: Text(_marca?.nome ?? 'Escolher'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _escolherMarca,
          ),
          ListTile(
            key: const Key('campo-modelo'),
            title: const Text('Modelo'),
            subtitle: Text(
              _modelo?.nome ??
                  (_marca == null ? 'Escolha a marca antes' : 'Escolher'),
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: _marca != null,
            onTap: _escolherModelo,
          ),
          ListTile(
            key: const Key('campo-motor'),
            title: const Text('Motor (opcional)'),
            subtitle: Text(_motor?.rotulo ?? 'Qualquer'),
            trailing: _motor == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    tooltip: 'Tirar o motor',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _motor = null),
                  ),
            onTap: _escolherMotor,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _campoAno('Ano inicial', _anoInicio, const Key('ano-inicio')),
                const SizedBox(width: 12),
                _campoAno('Ano final', _anoFim, const Key('ano-fim')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: _modelo == null || _salvando ? null : _adicionar,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Adicionar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
