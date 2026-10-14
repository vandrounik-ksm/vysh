import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/ports/secret_store.dart';

/// Секреты в системном хранилище:
/// Windows - Credential Manager / DPAPI, Linux - Secret Service (libsecret),
/// macOS - Keychain (доступен после первого разблокирования).
class KeyringSecretStore implements SecretStore {
  static FlutterSecureStorage _build() {
    if (kIsWeb) return const FlutterSecureStorage();
    return Platform.isMacOS
        ? const FlutterSecureStorage(
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock,
              // Классический (не data-protection) Keychain: не требует
              // keychain-access-groups и provisioning-профиля - приложение
              // без App Group, сборка без аккаунта Apple Developer.
              usesDataProtectionKeychain: false,
            ),
          )
        : const FlutterSecureStorage();
  }

  final _storage = _build();

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
