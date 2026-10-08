import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../provedores.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _enviando = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref
          .read(sessaoProvider.notifier)
          .entrar(_email.text.trim(), _senha.text);
      // Deu certo: o app troca de tela sozinho ao observar a sessão.
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _erro = e.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 64,
                        color: tema.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Manuais',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const Key('email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Informe o e-mail.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('senha'),
                        controller: _senha,
                        obscureText: !_senhaVisivel,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _entrar(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _senhaVisivel
                                ? 'Ocultar senha'
                                : 'Mostrar senha',
                            icon: Icon(
                              _senhaVisivel
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Informe a senha.'
                            : null,
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erro!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: tema.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _enviando ? null : _entrar,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _enviando
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
