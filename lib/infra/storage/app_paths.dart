import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Где vysh хранит свои файлы (хосты, настройки, known_hosts).
///
/// Всегда в профиле пользователя - неважно, откуда запущен exe.
/// Поэтому обновление = удалить старую папку с программой и распаковать
/// новую: хосты и настройки останутся.
///
/// * Android: getApplicationDocumentsDirectory() / vysh
/// * Windows: `%APPDATA%\vysh`
/// * Linux: `$XDG_CONFIG_HOME/vysh` (обычно `~/.config/vysh`)
/// * macOS: `getApplicationSupportDirectory()` / vysh (внутри App Sandbox)
/// * переменная `VYSH_CONFIG_DIR` (ПК) задаёт свою папку
class AppPaths {
  AppPaths._();

  static Directory? _configDir;

  static Directory get configDir {
    if (kIsWeb) return Directory('/vysh');
    try {
      return _configDir ?? Directory(_join(Directory.systemTemp.path, 'vysh'));
    } catch (_) {
      return Directory('/vysh');
    }
  }

  /// Папку профиля создать не удалось: данные временно пишутся во
  /// временную папку, и пользователь должен об этом узнать.
  static ({String path, String error})? initError;

  static Future<void> init() async {
    if (kIsWeb) return;
    String? path;
    try {
      path = await _resolve();
      final dir = Directory(path);
      await dir.create(recursive: true);
      _configDir = dir;
      await _migrateMacLegacy(dir);
    } catch (e) {
      initError = (path: path ?? '?', error: '$e');
    }
  }

  /// macOS: ранее (до App Sandbox) профиль жил в `~/.config/vysh`. При
  /// первом запуске новых версий переносим hosts/settings/known_hosts,
  /// если они там остались. Файлы копируются, а не переносятся: старые
  /// оставляем как резервную копию.
  static Future<void> _migrateMacLegacy(Directory target) async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      final legacy = Directory(_join(_realMacHome(), '.config/vysh'));
      if (!await legacy.exists()) return;
      var copied = false;
      for (final name in const ['hosts.json', 'settings.json', 'known_hosts.json']) {
        final src = File(_join(legacy.path, name));
        final dst = File(_join(target.path, name));
        if (await src.exists() && !await dst.exists()) {
          await src.copy(dst.path);
          copied = true;
        }
      }
      if (copied) {
        // Пароли из старого fallback-файла порта тоже переносим в новый.
        final old = File(_join(legacy.parent.path, '.vysh_secrets.json'));
        if (await old.exists()) {
          final support = await getApplicationSupportDirectory();
          final newFile = File(_join(support.path, '.vysh_secrets.json'));
          if (!await newFile.exists()) await old.copy(newFile.path);
        }
      }
    } catch (_) {
      // Миграция не критична: профиль просто начнётся с нуля.
    }
  }

  /// Домашний каталог пользователя вне контейнера App Sandbox.
  /// HOME под sandbox указывает на контейнер; настоящий дом -
  /// `/Users/<USER>`. Чтение из него разрешено sandbox.
  static String _realMacHome() {
    final env = Platform.environment;
    final user = env['USER'] ?? env['LOGNAME'] ?? '';
    if (user.isNotEmpty) return '/Users/$user';
    final home = env['HOME'] ?? '.';
    final i = home.indexOf('/Library/Containers/');
    return i > 0 ? home.substring(0, i) : home;
  }

  static File file(String name) => File(_join(configDir.path, name));

  /// Своя папка профиля для тестов.
  @visibleForTesting
  static set configDirForTest(Directory dir) => _configDir = dir;

  static Future<String> _resolve() async {
    if (kIsWeb) return 'vysh';
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final docs = await getApplicationDocumentsDirectory();
        return _join(docs.path, 'vysh');
      }
      final env = Platform.environment;
      // Отдельный профиль: демо-стенд для скриншотов, тесты (tools/demo).
      final custom = env['VYSH_CONFIG_DIR'];
      if (custom != null && custom.trim().isNotEmpty) return custom.trim();
      if (Platform.isWindows) {
        final base = env['APPDATA'] ?? env['USERPROFILE'] ?? '.';
        return _join(base, 'vysh');
      }
      if (Platform.isMacOS) {
        // App Sandbox: getApplicationSupportDirectory() лежит в контейнере
        // приложения и всегда доступен на запись - хосты и настройки там.
        final support = await getApplicationSupportDirectory();
        return _join(support.path, 'vysh');
      }
      final xdg = env['XDG_CONFIG_HOME'];
      final base = (xdg != null && xdg.isNotEmpty)
          ? xdg
          : _join(env['HOME'] ?? '.', '.config');
      return _join(base, 'vysh');
    } catch (_) {
      return 'vysh';
    }
  }

  static String _join(String a, String b) {
    if (kIsWeb) return '$a/$b';
    try {
      return '$a${Platform.pathSeparator}$b';
    } catch (_) {
      return '$a/$b';
    }
  }
}
