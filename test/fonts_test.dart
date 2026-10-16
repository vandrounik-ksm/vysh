// Шрифты терминала: разбор файлов, моноширинность, значение настройки.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/app/settings/app_settings.dart';
import 'package:vysh/app/settings/terminal_font.dart';
import 'package:vysh/domain/services/font_info.dart';
import 'package:vysh/infra/platform/font_files.dart';
import 'package:vysh/infra/storage/app_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('разбор шрифта', () {
    test('шрифт из сборки: имя семейства и моноширинность', () {
      final info = FontFiles.readInfo('assets/fonts/JetBrainsMonoNL-Regular.ttf');
      expect(info, hasLength(1));
      expect(info.first.family, 'JetBrains Mono NL');
      expect(info.first.monospace, isTrue);
    });

    test('не шрифт и пустой файл не роняют разбор', () async {
      final dir = await Directory.systemTemp.createTemp('vysh-font-');
      try {
        final junk = File('${dir.path}/junk.ttf')..writeAsStringSync('not a font at all');
        final empty = File('${dir.path}/empty.ttf')..writeAsBytesSync(const []);
        expect(FontFiles.readInfo(junk.path), isEmpty);
        expect(FontFiles.readInfo(empty.path), isEmpty);
        expect(FontFiles.readInfo('${dir.path}/missing.ttf'), isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('ширины глифов', () {
      expect(FontInfoParser.widthsLookMonospace([600, 600, 600, 0, 600]), isTrue);
      // Двойная ширина у значков и полноширинных символов.
      expect(FontInfoParser.widthsLookMonospace([500, 500, 500, 1000, 1000, 1000]), isTrue);
      expect(FontInfoParser.widthsLookMonospace([278, 556, 833, 611, 500, 722, 584]), isFalse);
      expect(FontInfoParser.widthsLookMonospace(const []), isFalse);
    });
  });

  group('свои шрифты', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vysh-fonts-');
      AppPaths.configDirForTest = dir;
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('файл копируется в fonts/ под безопасным именем, без перезаписи', () async {
      final src = File('${dir.path}/My Font (1).ttf');
      await File('assets/fonts/JetBrainsMonoNL-Regular.ttf').copy(src.path);

      final a = await FontFiles.addUser(src.path);
      final b = await FontFiles.addUser(src.path);
      expect(a.fileName, 'My_Font_1_.ttf');
      expect(b.fileName, 'My_Font_1_-2.ttf');
      expect(a.family, 'JetBrains Mono NL');
      expect(FontFiles.listUser().map((f) => f.fileName), containsAll([a.fileName, b.fileName]));

      await FontFiles.deleteUser(a.fileName);
      expect(FontFiles.listUser().map((f) => f.fileName), [b.fileName]);
    });

    test('не шрифт не добавляется', () async {
      final src = File('${dir.path}/fake.ttf')..writeAsStringSync('hello');
      await expectLater(
        FontFiles.addUser(src.path),
        throwsA(isA<AddFontException>().having((e) => e.error, 'error', AddFontError.notFont)),
      );
      expect(FontFiles.listUser(), isEmpty);
    });
  });

  group('настройка шрифта', () {
    test('значения и запасная цепочка', () {
      expect(TerminalFont.familyOf(''), TerminalFont.defaultFamily);
      expect(TerminalFont.familyOf(TerminalFont.system('Iosevka')), 'Iosevka');
      expect(TerminalFont.familyOf(TerminalFont.file('x.ttf')), UserFont.familyFor('x.ttf'));

      final fallback = TerminalFont.fallbackOf(TerminalFont.system('Iosevka'));
      expect(fallback.first, TerminalFont.defaultFamily);
      expect(fallback, contains(TerminalFont.bundledFamily));
      expect(fallback.last, 'monospace');
      expect(fallback.toSet(), hasLength(fallback.length));
      expect(TerminalFont.fallbackOf(''), isNot(contains(TerminalFont.defaultFamily)));
    });

    test('сохраняется и читается, мусор даёт значения по умолчанию', () {
      final s = AppSettings.fromJson(const AppSettings(
        terminalFont: 'system:Iosevka',
        terminalLineHeight: 1.45,
      ).toJson());
      expect(s.terminalFont, 'system:Iosevka');
      expect(s.terminalLineHeight, 1.45);

      final bad = AppSettings.fromJson({'terminalFont': 5, 'terminalLineHeight': 'NaN'});
      expect(bad.terminalFont, '');
      expect(bad.terminalLineHeight, 1.2);
      expect(AppSettings.fromJson({'terminalLineHeight': 9}).terminalLineHeight, 1.6);
    });
  });
}
