import 'dart:ui';

/// Цвета, пришедшие извне: акцент системы или файл дотов.
class ExternalColors {
  const ExternalColors({
    required this.seed,
    required this.source,
    this.path,
    this.roles = const {},
    this.ansi,
    this.terminalBackground,
    this.terminalForeground,
    this.brightness,
  });

  /// Основной цвет - из него строится вся схема Material You.
  final Color seed;

  /// Источник: имя программы («pywal», «caelestia», «Catppuccin Mocha»)
  /// или один из кодов ниже - их название переводит интерфейс.
  final String source;

  static const windowsAccent = 'windows-accent';
  static const portalAccent = 'portal-accent';
  static const colorsFile = 'colors-file';

  /// Файл, из которого прочитано (для показа в настройках).
  final String? path;

  /// Готовые роли M3 по яркости (matugen, caelestia): перекрывают сгенерированные.
  final Map<Brightness, Map<String, Color>> roles;

  /// 16 цветов терминала (pywal, caelestia).
  final List<Color>? ansi;
  final Color? terminalBackground;
  final Color? terminalForeground;

  /// Режим, который задают доты (тёмный/светлый). null - не задают.
  final Brightness? brightness;

  bool sameAs(ExternalColors? o) =>
      o != null &&
      o.seed == seed &&
      o.source == source &&
      o.path == path &&
      o.brightness == brightness &&
      o.terminalBackground == terminalBackground &&
      o.terminalForeground == terminalForeground &&
      _listEq(o.ansi, ansi) &&
      _rolesEq(o.roles, roles);

  static bool _listEq(List<Color>? a, List<Color>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _rolesEq(Map<Brightness, Map<String, Color>> a, Map<Brightness, Map<String, Color>> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      final x = a[k]!, y = b[k];
      if (y == null || x.length != y.length) return false;
      for (final r in x.keys) {
        if (x[r] != y[r]) return false;
      }
    }
    return true;
  }
}
