import 'package:flutter/material.dart';

import 'cadastros_tab.dart';
import 'pendentes_tab.dart';
import 'usuarios_tab.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administração'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pendentes'),
              Tab(text: 'Cadastros'),
              Tab(text: 'Usuários'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [PendentesTab(), CadastrosTab(), UsuariosTab()],
        ),
      ),
    );
  }
}
