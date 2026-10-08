import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../auth/sessao.dart';
import '../provedores.dart';
import '../comum/avisos.dart';

final usuariosProvider = FutureProvider.autoDispose<List<Usuario>>(
  (ref) => ref.watch(apiProvider).usuarios(),
);

class UsuariosTab extends ConsumerWidget {
  const UsuariosTab({super.key});

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Usuario? usuario,
  ) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UsuarioPage(usuario: usuario)),
    );
    if (salvou == true) ref.invalidate(usuariosProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(context, ref, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Novo usuário'),
      ),
      body: usuarios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => Aviso(
          icone: Icons.cloud_off,
          texto: ApiClient.traduzir(erro).mensagem,
          acao: FilledButton.tonal(
            onPressed: () => ref.invalidate(usuariosProvider),
            child: const Text('Tentar de novo'),
          ),
        ),
        data: (lista) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: lista.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = lista[i];
            return ListTile(
              leading: Icon(
                u.admin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline,
              ),
              title: Text(u.nome),
              subtitle: Text(
                '${u.email} · ${u.admin ? 'admin' : 'mecânico'}${u.ativo ? '' : ' · desativado'}',
              ),
              enabled: u.ativo,
              onTap: () => _editar(context, ref, u),
            );
          },
        ),
      ),
    );
  }
}

/// Cria ([usuario] nulo) ou edita um usuário. Devolve true se salvou.
class UsuarioPage extends ConsumerStatefulWidget {
  const UsuarioPage({super.key, this.usuario});

  final Usuario? usuario;

  @override
  ConsumerState<UsuarioPage> createState() => _UsuarioPageState();
}

class _UsuarioPageState extends ConsumerState<UsuarioPage> {
  final _formulario = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.usuario?.nome);
  late final _email = TextEditingController(text: widget.usuario?.email);
  final _senha = TextEditingController();
  late var _papel = widget.usuario?.papel ?? 'mecanico';
  late var _ativo = widget.usuario?.ativo ?? true;
  var _salvando = false;

  bool get _novo => widget.usuario == null;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref
          .read(apiProvider)
          .salvarUsuario(
            id: widget.usuario?.id,
            nome: _nome.text.trim(),
            email: _email.text.trim(),
            papel: _papel,
            ativo: _ativo,
            senha: _senha.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      avisar(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final euMesmo = switch (ref.watch(sessaoProvider)) {
      SessaoLogada(:final usuario) => usuario.id == widget.usuario?.id,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(title: Text(_novo ? 'Novo usuário' : 'Editar usuário')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('usuario-nome'),
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('usuario-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Informe o e-mail.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('usuario-senha'),
              controller: _senha,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _novo
                    ? 'Senha'
                    : 'Nova senha (vazio mantém a atual)',
                helperText: 'De 8 a 72 caracteres.',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final senha = v ?? '';
                if (senha.isEmpty) return _novo ? 'Informe a senha.' : null;
                return senha.length < 8 ? 'Mínimo de 8 caracteres.' : null;
              },
            ),
            const SizedBox(height: 16),
            // O backend recusa o admin rebaixar ou desativar a si mesmo.
            DropdownButtonFormField<String>(
              initialValue: _papel,
              decoration: const InputDecoration(
                labelText: 'Papel',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'mecanico', child: Text('Mecânico')),
                DropdownMenuItem(value: 'admin', child: Text('Administrador')),
              ],
              onChanged: euMesmo ? null : (v) => setState(() => _papel = v!),
            ),
            if (!_novo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                subtitle: const Text('Desativado não consegue entrar.'),
                value: _ativo,
                onChanged: euMesmo ? null : (v) => setState(() => _ativo = v),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('usuario-salvar'),
              onPressed: _salvando ? null : _salvar,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
