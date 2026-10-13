/// Хранилище секретов (пароли, парольные фразы ключей).
/// Реализация по умолчанию - системный keyring.
abstract interface class SecretStore {
  /// null - секрета нет. Недоступное хранилище (нет keyring-демона и т. п.)
  /// - исключение [SecretStoreUnavailable], а не «секрета нет».
  Future<String?> read(String key);

  /// Бросает исключение, если хранилище недоступно.
  Future<void> write(String key, String value);

  /// Бросает исключение, если хранилище недоступно.
  Future<void> delete(String key);
}

/// Системное хранилище секретов недоступно.
class SecretStoreUnavailable implements Exception {
  const SecretStoreUnavailable(this.detail);
  final String detail;
  @override
  String toString() => 'SecretStoreUnavailable($detail)';
}

/// Ключи секретов для хоста.
String passwordKey(String hostId) => 'vysh.password.$hostId';
String passphraseKey(String hostId) => 'vysh.passphrase.$hostId';
