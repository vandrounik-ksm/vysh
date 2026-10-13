// Правила слоёв (docs/ARCHITECTURE.md, раздел 3): ui → app → domain ← infra.
// Нарушение импорта ломает этот тест, а значит и CI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Импорты файлов [dir] в виде путей внутри lib/ (или `package:`/`dart:`).
Map<String, List<String>> _imports(String dir) {
  final result = <String, List<String>>{};
  final re = RegExp(r'''^(?:import|export)\s+'([^']+)'.*;''', multiLine: true);
  for (final e in Directory('lib/$dir').listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final path = e.path.replaceAll('\\', '/');
    final from = path.substring(0, path.lastIndexOf('/'));
    final list = <String>[];
    for (final m in re.allMatches(e.readAsStringSync())) {
      final uri = m.group(1)!;
      if (uri.contains(':')) {
        list.add(uri.startsWith('package:vysh/') ? 'lib/${uri.substring(13)}' : uri);
      } else {
        list.add(Uri.parse('$from/').resolve(uri).path);
      }
    }
    result[path] = list;
  }
  return result;
}

void _expectNone(String dir, bool Function(String import) forbidden, String rule) {
  final bad = <String>[
    for (final MapEntry(key: file, value: imports) in _imports(dir).entries)
      for (final i in imports)
        if (forbidden(i)) '$file → $i',
  ];
  expect(bad, isEmpty, reason: rule);
}

void main() {
  test('domain не зависит от остальных слоёв и сторонних библиотек', () {
    _expectNone(
      'domain',
      (i) => !i.startsWith('dart:') && !i.startsWith('lib/domain/'),
      'domain: только dart: и сам domain',
    );
  });

  test('infra не знает про app и ui', () {
    _expectNone(
      'infra',
      (i) => i.startsWith('lib/app/') || i.startsWith('lib/ui/') || i.startsWith('lib/l10n/'),
      'infra реализует порты domain и не зависит от верхних слоёв',
    );
  });

  test('app не знает про ui', () {
    _expectNone('app', (i) => i.startsWith('lib/ui/'), 'app: контроллеры и связывание, без виджетов');
  });
}
