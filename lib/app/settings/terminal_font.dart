import '../../infra/platform/capabilities.dart';
import '../../infra/platform/font_files.dart';

/// Шрифт терминала из настройки `terminalFont`.
///
/// * `''` - по умолчанию для платформы;
/// * `system:<семейство>` - шрифт, установленный в системе;
/// * `file:<имя файла>` - свой файл из папки профиля `fonts/`.
///
/// Запасная цепочка остаётся всегда: символы, которых нет в выбранном
/// шрифте (кириллица, рамки, значки), берутся из неё.
abstract final class TerminalFont {
  /// Шрифт в сборке (assets/fonts, OFL). Основной на macOS и Android,
  /// на Windows и Linux только в запасной цепочке.
  static const bundledFamily = 'JetBrains Mono NL';

  static const _systemPrefix = 'system:';
  static const _filePrefix = 'file:';

  static String system(String family) => '$_systemPrefix$family';
  static String file(String fileName) => '$_filePrefix$fileName';

  static String? systemFamily(String value) =>
      value.startsWith(_systemPrefix) ? value.substring(_systemPrefix.length) : null;

  static String? fileName(String value) =>
      value.startsWith(_filePrefix) ? value.substring(_filePrefix.length) : null;

  /// Шрифт по умолчанию. На macOS и Android своих моноширинных шрифтов нет
  /// (Menlo устарел, на Android только Droid Sans Mono), поэтому там свой.
  static String get defaultFamily =>
      PlatformCapabilities.bundledMonoFont ? bundledFamily : 'Cascadia Mono';

  /// Семейство для Flutter по значению настройки.
  static String familyOf(String value) {
    final sys = systemFamily(value);
    if (sys != null && sys.isNotEmpty) return sys;
    final f = fileName(value);
    if (f != null && f.isNotEmpty) return UserFont.familyFor(f);
    return defaultFamily;
  }

  /// Запасные шрифты для [value]: сначала шрифт по умолчанию, потом общая цепочка.
  static List<String> fallbackOf(String value) {
    final primary = familyOf(value);
    return [
      if (primary != defaultFamily) defaultFamily,
      for (final f in _chain)
        if (f != primary && f != defaultFamily) f,
    ];
  }

  static const _chain = <String>[
    'Cascadia Mono',
    'JetBrainsMono Nerd Font',
    'JetBrains Mono',
    'Consolas',
    'DejaVu Sans Mono',
    'Liberation Mono',
    'Menlo',
    bundledFamily,
    // Значки Nerd Font, рамки и символы, эмодзи.
    'Symbols Nerd Font Mono',
    'Symbols Nerd Font',
    'Segoe UI Symbol',
    'Noto Sans Symbols 2',
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
    'Courier New',
    'monospace',
  ];

  /// Межстрочный интервал: пределы и значение по умолчанию (как в xterm2).
  static const minLineHeight = 1.0;
  static const maxLineHeight = 1.6;
  static const defaultLineHeight = 1.2;
}
