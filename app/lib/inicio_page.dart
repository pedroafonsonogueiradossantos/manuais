import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin/admin_page.dart';
import 'api/api_client.dart';
import 'api/modelos.dart';
import 'conta/configuracoes_page.dart';
import 'documentos/busca_page.dart';
import 'offline/listas_locais.dart';
import 'provedores.dart';

/// Tela principal do usuário logado: buscar, favoritos e baixados.
class InicioPage extends ConsumerStatefulWidget {
  const InicioPage({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends ConsumerState<InicioPage> {
  var _aba = 0;
  late final Future<void> _preparo = _preparar();

  /// O banco local precisa estar com os dados do usuário certo antes de
  /// qualquer aba ler dele.
  Future<void> _preparar() async {
    final offline = ref.read(offlineProvider);
    await offline.prepararPara(widget.usuario);
    // Em segundo plano; sem internet a cópia local continua valendo.
    offline.sincronizarFavoritos().catchError((Object e) {
      if (e is! ApiErro) throw e;
    });
  }

  void _abrir(Widget pagina) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    return Scaffold(
      appBar: AppBar(
        title: Text(const ['Manuais', 'Favoritos', 'Baixados'][_aba]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Conta',
            icon: const Icon(Icons.account_circle),
            onSelected: (opcao) => switch (opcao) {
              'admin' => _abrir(const AdminPage()),
              'config' => _abrir(const ConfiguracoesPage()),
              _ => ref.read(sessaoProvider.notifier).sair(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text('${usuario.nome}\n${usuario.email}'),
              ),
              if (usuario.admin)
                const PopupMenuItem(
                  value: 'admin',
                  child: Text('Administração'),
                ),
              const PopupMenuItem(
                value: 'config',
                child: Text('Configurações'),
              ),
              const PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: FutureBuilder(
        future: _preparo,
        builder: (context, preparo) {
          if (preparo.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          // IndexedStack mantém o texto digitado e a rolagem de cada aba.
          return IndexedStack(
            index: _aba,
            children: const [BuscaTab(), FavoritosTab(), BaixadosTab()],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_done),
            label: 'Baixados',
          ),
        ],
      ),
    );
  }
}
