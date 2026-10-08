import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/login_page.dart';
import 'auth/sessao.dart';
import 'inicio_page.dart';
import 'provedores.dart';

void main() {
  runApp(const ProviderScope(child: ManuaisApp()));
}

class ManuaisApp extends ConsumerWidget {
  const ManuaisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider);
    return MaterialApp(
      title: 'Manuais',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.dark,
      ),
      // A chave troca a árvore inteira ao logar/deslogar: nenhuma tela de um
      // usuário sobrevive para o próximo.
      home: KeyedSubtree(
        key: ValueKey(sessao.runtimeType),
        child: switch (sessao) {
          SessaoCarregando() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          SessaoDeslogada() => const LoginPage(),
          SessaoLogada(:final usuario) => InicioPage(usuario: usuario),
        },
      ),
    );
  }
}
