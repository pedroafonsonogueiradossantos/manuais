import 'package:manuais/auth/cofre.dart';

class CofreMemoria implements Cofre {
  final dados = <String, String>{};

  @override
  Future<String?> ler(String chave) async => dados[chave];

  @override
  Future<void> gravar(String chave, String valor) async => dados[chave] = valor;

  @override
  Future<void> apagar(String chave) async => dados.remove(chave);
}
