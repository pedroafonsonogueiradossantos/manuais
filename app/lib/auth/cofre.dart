import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda segredos do app (o token de sessão).
abstract class Cofre {
  Future<String?> ler(String chave);
  Future<void> gravar(String chave, String valor);
  Future<void> apagar(String chave);
}

/// Keystore no Android, Keychain no iOS.
class CofreSeguro implements Cofre {
  const CofreSeguro();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> ler(String chave) => _storage.read(key: chave);

  @override
  Future<void> gravar(String chave, String valor) =>
      _storage.write(key: chave, value: valor);

  @override
  Future<void> apagar(String chave) => _storage.delete(key: chave);
}
