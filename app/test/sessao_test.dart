import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/api/api_client.dart';
import 'package:manuais/auth/sessao.dart';
import 'package:manuais/provedores.dart';

import 'apoio/adaptador_falso.dart';
import 'apoio/cofre_memoria.dart';

void main() {
  late CofreMemoria cofre;

  ProviderContainer criar(Future<ResponseBody> Function(RequestOptions) responder) {
    final container = ProviderContainer(
      overrides: [
        cofreProvider.overrideWithValue(cofre),
        adaptadorHttpProvider.overrideWithValue(AdaptadorFalso(responder)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Espera a restauração inicial terminar.
  Future<Sessao> pronta(ProviderContainer c) async {
    c.read(sessaoProvider);
    await pumpEventQueue();
    return c.read(sessaoProvider);
  }

  setUp(() => cofre = CofreMemoria());

  test('sem token guardado começa deslogada', () async {
    final c = criar((_) async => respostaJson(500, null));
    expect(c.read(sessaoProvider), isA<SessaoCarregando>());
    expect(await pronta(c), isA<SessaoDeslogada>());
  });

  test('entrar guarda token e usuário; as chamadas seguintes levam o token', () async {
    late RequestOptions ultimo;
    final c = criar((pedido) async {
      ultimo = pedido;
      return pedido.path == '/auth/login'
          ? respostaJson(200, {'token': 'tok', 'usuario': usuarioJson})
          : respostaJson(200, []);
    });
    await pronta(c);

    await c.read(sessaoProvider.notifier).entrar('ana@exemplo.com', 'segredo');

    final s = c.read(sessaoProvider) as SessaoLogada;
    expect(s.usuario.nome, 'Ana');
    expect(cofre.dados['token'], 'tok');
    expect(jsonDecode(cofre.dados['usuario']!)['email'], 'ana@exemplo.com');

    await c.read(apiProvider).marcas();
    expect(ultimo.headers['Authorization'], 'Bearer tok');
  });

  test('login recusado propaga o erro e continua deslogada', () async {
    final c = criar(
      (_) async => respostaErro(401, 'credenciais_invalidas', 'E-mail ou senha incorretos.'),
    );
    await pronta(c);

    await expectLater(
      c.read(sessaoProvider.notifier).entrar('a@b.c', 'x'),
      throwsA(isA<ApiErro>()),
    );
    expect(c.read(sessaoProvider), isA<SessaoDeslogada>());
    expect(cofre.dados, isEmpty);
  });

  test('restaura a sessão guardada sem usar a rede', () async {
    cofre.dados['token'] = 'tok';
    cofre.dados['usuario'] = jsonEncode(usuarioJson);
    var chamadas = 0;
    final c = criar((_) async {
      chamadas++;
      return respostaJson(200, null);
    });

    final s = await pronta(c);

    expect(s, isA<SessaoLogada>());
    expect((s as SessaoLogada).usuario.admin, isTrue);
    expect(chamadas, 0);
  });

  test('401 em qualquer chamada desloga e limpa o cofre', () async {
    cofre.dados['token'] = 'vencido';
    cofre.dados['usuario'] = jsonEncode(usuarioJson);
    final c = criar(
      (_) async => respostaErro(401, 'nao_autenticado', 'Faça login para continuar.'),
    );
    await pronta(c);

    await expectLater(c.read(apiProvider).marcas(), throwsA(isA<ApiErro>()));
    await pumpEventQueue();

    expect(c.read(sessaoProvider), isA<SessaoDeslogada>());
    expect(cofre.dados, isEmpty);
  });

  test('dado corrompido no cofre vira deslogada em vez de travar', () async {
    cofre.dados['token'] = 'tok';
    cofre.dados['usuario'] = '{isto não é json';
    final c = criar((_) async => respostaJson(200, null));

    expect(await pronta(c), isA<SessaoDeslogada>());
  });
}
