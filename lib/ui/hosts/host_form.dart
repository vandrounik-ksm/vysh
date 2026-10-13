import 'package:flutter/widgets.dart';

import '../../domain/models/host.dart';
import '../theme/app_theme.dart' show hostColors;

/// Состояние формы редактора хоста: поля ввода, выбранные варианты и сборка
/// [Host]. Секции формы - виджеты без своего состояния, они только читают
/// и меняют эту модель; перестраиваются по [notifyListeners].
class HostForm extends ChangeNotifier {
  HostForm(Host? h, {required String initialLabel})
      : label = TextEditingController(text: initialLabel),
        address = TextEditingController(text: h?.address ?? ''),
        port = TextEditingController(text: '${h?.port ?? 22}'),
        user = TextEditingController(text: h?.username ?? ''),
        password = TextEditingController(),
        keyPath = TextEditingController(text: h?.keyPath ?? ''),
        group = TextEditingController(text: h?.group ?? ''),
        _auth = h?.auth ?? AuthMethod.password,
        _color = h?.color ?? hostColors.first,
        _keepAliveSeconds = h?.keepAliveSeconds {
    _lastAddressLen = address.text.length;
    // Подсказка «Название» повторяет адрес, чипы групп - поле группы.
    address.addListener(notifyListeners);
    group.addListener(notifyListeners);
  }

  final TextEditingController label;
  final TextEditingController address;
  final TextEditingController port;
  final TextEditingController user;
  final TextEditingController password;
  final TextEditingController keyPath;
  final TextEditingController group;

  AuthMethod get auth => _auth;
  AuthMethod _auth;
  set auth(AuthMethod v) => _change(() => _auth = v);

  int get color => _color;
  int _color;
  set color(int v) => _change(() => _color = v);

  /// null - из глобальных настроек, 0 - выключен.
  int? get keepAliveSeconds => _keepAliveSeconds;
  int? _keepAliveSeconds;
  set keepAliveSeconds(int? v) => _change(() => _keepAliveSeconds = v);

  bool get rememberPassword => _rememberPassword;
  bool _rememberPassword = true;
  set rememberPassword(bool v) => _change(() => _rememberPassword = v);

  bool get obscurePassword => _obscure;
  bool _obscure = true;
  void toggleObscure() => _change(() => _obscure = !_obscure);

  void _change(VoidCallback f) {
    f();
    notifyListeners();
  }

  int _lastAddressLen = 0;

  /// Вставили `user@host:port` в поле адреса - раскладываем по полям.
  /// Срабатывает только на вставку (скачок длины), а не при наборе по символу.
  void onAddressChanged(String v) {
    final quick = pastedAddress(v, previousLength: _lastAddressLen);
    _lastAddressLen = v.length;
    if (quick == null) return;
    address.value = TextEditingValue(
      text: quick.address,
      selection: TextSelection.collapsed(offset: quick.address.length),
    );
    port.text = '${quick.port}';
    if (v.trim().contains('@')) user.text = quick.username;
    _lastAddressLen = quick.address.length;
  }

  /// Хост из полей формы (поля уже проверены валидаторами).
  Host toHost({required String id, DateTime? lastConnectedAt}) {
    final key = keyPath.text.trim();
    return Host(
      id: id,
      label: label.text.trim(),
      address: address.text.trim(),
      port: int.parse(port.text.trim()),
      // Пусто - значит root (он и показан серой подсказкой в поле).
      username: user.text.trim().isEmpty ? 'root' : user.text.trim(),
      auth: _auth,
      keyPath: _auth == AuthMethod.key && key.isNotEmpty ? key : null,
      group: group.text.trim(),
      color: _color,
      lastConnectedAt: lastConnectedAt,
      keepAliveSeconds: _keepAliveSeconds,
    );
  }

  static bool validPort(String? v) {
    final p = int.tryParse(v ?? '');
    return p != null && p >= 1 && p <= 65535;
  }

  @override
  void dispose() {
    for (final c in [label, address, port, user, password, keyPath, group]) {
      c.dispose();
    }
    super.dispose();
  }
}
