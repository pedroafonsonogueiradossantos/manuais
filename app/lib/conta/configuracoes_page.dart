import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../comum/avisos.dart';
import '../provedores.dart';

final _autoBaixarProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(offlineProvider).autoBaixar(),
);

class ConfiguracoesPage extends ConsumerWidget {
  const ConfiguracoesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoBaixar = ref.watch(_autoBaixarProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('auto-baixar'),
            title: const Text('Baixar favoritos automaticamente'),
            subtitle: const Text('Só no Wi-Fi e com o app aberto.'),
            value: autoBaixar,
            onChanged: (ligado) async {
              // Não espera os downloads: eles seguem em segundo plano.
              final pronto = ref
                  .read(offlineProvider)
                  .definirAutoBaixar(ligado);
              await Future<void>.delayed(Duration.zero);
              ref.invalidate(_autoBaixarProvider);
              await pronto;
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Trocar senha'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TrocarSenhaPage())),
          ),
        ],
      ),
    );
  }
}

class TrocarSenhaPage extends ConsumerStatefulWidget {
  const TrocarSenhaPage({super.key});

  @override
  ConsumerState<TrocarSenhaPage> createState() => _TrocarSenhaPageState();
}

class _TrocarSenhaPageState extends ConsumerState<TrocarSenhaPage> {
  final _formulario = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();
  var _enviando = false;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _trocar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await ref
          .read(sessaoProvider.notifier)
          .trocarSenha(_atual.text, _nova.text);
      if (!mounted) return;
      avisar(context, 'Senha trocada.');
      Navigator.of(context).pop();
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      avisar(context, e.mensagem);
    }
  }

  Widget _campo(
    String chave,
    String rotulo,
    TextEditingController c,
    FormFieldValidator<String> v,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: Key(chave),
        controller: c,
        obscureText: true,
        decoration: InputDecoration(
          labelText: rotulo,
          border: const OutlineInputBorder(),
        ),
        validator: v,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trocar senha')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _campo(
              'senha-atual',
              'Senha atual',
              _atual,
              (v) => (v == null || v.isEmpty) ? 'Informe a senha atual.' : null,
            ),
            _campo(
              'senha-nova',
              'Nova senha',
              _nova,
              (v) => (v == null || v.length < 8)
                  ? 'Mínimo de 8 caracteres.'
                  : null,
            ),
            _campo(
              'senha-confirmacao',
              'Repita a nova senha',
              _confirmacao,
              (v) => v != _nova.text ? 'As senhas não conferem.' : null,
            ),
            FilledButton(
              key: const Key('trocar-senha'),
              onPressed: _enviando ? null : _trocar,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Trocar senha'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
