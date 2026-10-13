import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/ports/secret_store.dart';

/// Секреты в системном хранилище:
/// Windows - Credential Manager / DPAPI, Linux - Secret Service (libsecret).
class KeyringSecretStore implements SecretStore {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      // Нет keyring-демона (голый WM без gnome-keyring/kwallet) и т.п.
      throw SecretStoreUnavailable('$e');
    }
  }

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  /// Бросает исключение, если хранилище недоступно: «пароль удалён»
  /// можно показывать только после настоящего удаления.
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
