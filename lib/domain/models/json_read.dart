/// Чтение полей JSON без исключений: значение неверного типа считается
/// отсутствующим (и берётся значение по умолчанию), а не роняет загрузку
/// всего файла. Числа, записанные строкой (`"port": "22"`), понимаем.
extension JsonRead on Map<String, Object?> {
  String? str(String key) {
    final v = this[key];
    return v is String ? v : null;
  }

  int? integer(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num && v.isFinite) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  double? dbl(String key) {
    final v = this[key];
    if (v is num && v.isFinite) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  bool? boolean(String key) {
    final v = this[key];
    if (v is bool) return v;
    if (v == 'true') return true;
    if (v == 'false') return false;
    return null;
  }
}
