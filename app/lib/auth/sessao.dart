import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../provedores.dart';

sealed class Sessao {
  const Sessao();
}

/// Ainda lendo o token guardado no aparelho.
class SessaoCarregando extends Sessao {
  const SessaoCarregando();
}

class SessaoDeslogada extends Sessao {
  const SessaoDeslogada();
}

class SessaoLogada extends Sessao {
  const SessaoLogada({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;
}

const _chaveToken = 'token';
const _chaveUsuario = 'usuario';

class SessaoNotifier extends Notifier<Sessao> {
  @override
  Sessao build() {
    _restaurar();
    return const SessaoCarregando();
  }

  /// Restaura a sessão guardada sem depender de rede, para o app abrir
  /// offline. Se o token não valer mais, o primeiro 401 da API desloga.
  Future<void> _restaurar() async {
    final cofre = ref.read(cofreProvider);
    Sessao restaurada = const SessaoDeslogada();
    try {
      final token = await cofre.ler(_chaveToken);
      final usuario = await cofre.ler(_chaveUsuario);
      if (token != null && usuario != null) {
        restaurada = SessaoLogada(
          token: token,
          usuario: Usuario.fromJson(
            jsonDecode(usuario) as Map<String, dynamic>,
          ),
        );
      }
    } catch (_) {
      // Cofre ilegível ou dado corrompido: melhor pedir login de novo.
    }
    if (!ref.mounted || state is! SessaoCarregando) return;
    state = restaurada;
  }

  /// Lança [ApiErro] se o login falhar.
  Future<void> entrar(String email, String senha) async {
    final r = await ref.read(apiProvider).login(email, senha);
    final cofre = ref.read(cofreProvider);
    await cofre.gravar(_chaveToken, r.token);
    await cofre.gravar(_chaveUsuario, jsonEncode(r.usuario.toJson()));
    state = SessaoLogada(token: r.token, usuario: r.usuario);
  }

  /// Lança [ApiErro] se a senha atual estiver errada ou a nova for inválida.
  Future<void> trocarSenha(String atual, String nova) async {
    final sessao = state;
    if (sessao is! SessaoLogada) return;
    final token = await ref.read(apiProvider).trocarSenha(atual, nova);
    await ref.read(cofreProvider).gravar(_chaveToken, token);
    state = SessaoLogada(token: token, usuario: sessao.usuario);
  }

  Future<void> sair() async {
    if (state is SessaoDeslogada) return;
    state = const SessaoDeslogada();
    final cofre = ref.read(cofreProvider);
    await cofre.apagar(_chaveToken);
    await cofre.apagar(_chaveUsuario);
  }
}
