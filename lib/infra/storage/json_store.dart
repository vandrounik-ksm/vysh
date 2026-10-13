import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_paths.dart';

/// Ошибка записи одного из файлов конфигурации - UI показывает её пользователю.
typedef JsonStoreFailure = ({String fileName, String message});

/// Простое хранилище одного JSON-файла в папке конфигурации.
///
/// Чтение синхронное (на старте, файлы маленькие), запись - асинхронная,
/// последовательная и атомарная: временный файл + rename поверх старого
/// (на Windows Dart делает MoveFileEx с заменой). Прежняя версия остаётся
/// в `.bak`, битый файл перед заменой сохраняется в `.corrupt-<время>`.
class JsonStore {
  JsonStore(this.fileName);

  final String fileName;
  Future<void> _queue = Future.value();
  static final Map<String, Object?> _webStore = {};
  static final _preserved = <String>{};

  /// Последняя неудачная запись (null - всё сохранено).
  static final failure = ValueNotifier<JsonStoreFailure?>(null);

  File get file => AppPaths.file(fileName);
  File get _tmp => File('${file.path}.tmp');
  File get _bak => File('${file.path}.bak');

  Object? readSync() {
    if (kIsWeb) {
      return _webStore[fileName];
    }
    // Основной файл, затем недописанная замена (если она целая), затем копия.
    final main = _tryRead(file, keepCorrupt: true);
    if (main.ok) return main.value;
    for (final f in [_tmp, _bak]) {
      final r = _tryRead(f);
      if (r.ok && r.value != null) {
        debugPrint('vysh: $fileName восстановлен из ${f.path}');
        return r.value;
      }
    }
    return null;
  }

  /// ok=false - файла нет или он не читается/битый.
  ({bool ok, Object? value}) _tryRead(File f, {bool keepCorrupt = false}) {
    try {
      if (!f.existsSync()) return (ok: false, value: null);
      final text = f.readAsStringSync();
      if (text.trim().isEmpty) return (ok: false, value: null);
      return (ok: true, value: jsonDecode(text));
    } catch (e) {
      // Битый файл не должен ронять приложение, но и затирать его молча нельзя:
      // откладываем копию рядом, чтобы данные можно было достать руками.
      if (keepCorrupt && _preserved.add(f.path)) {
        try {
          final stamp = DateTime.now().millisecondsSinceEpoch;
          f.copySync('${f.path}.corrupt-$stamp');
        } catch (_) {}
        debugPrint('vysh: $fileName повреждён: $e');
      }
      return (ok: false, value: null);
    }
  }

  /// Записать данные. Future завершается после фактической записи и
  /// возвращает false при ошибке (она же публикуется в [failure]).
  Future<bool> write(Object? data) {
    if (kIsWeb) {
      _webStore[fileName] = data;
      return Future.value(true);
    }
    final text = const JsonEncoder.withIndent('  ').convert(data);
    final result = Completer<bool>();
    _queue = _queue.then((_) async {
      try {
        await _replace(text);
        if (failure.value?.fileName == fileName) failure.value = null;
        result.complete(true);
      } catch (e) {
        debugPrint('vysh: не удалось сохранить $fileName: $e');
        failure.value = (fileName: fileName, message: '$e');
        result.complete(false);
      }
    });
    return result.future;
  }

  Future<void> _replace(String text) async {
    final tmp = _tmp;
    await tmp.parent.create(recursive: true);
    await tmp.writeAsString(text, flush: true);
    if (await file.exists()) {
      try {
        await file.copy(_bak.path);
      } catch (_) {
        // Копия - страховка, без неё запись всё равно делаем.
      }
    }
    // Атомарная замена: основной файл в любой момент либо старый, либо новый.
    await tmp.rename(file.path);
  }
}
