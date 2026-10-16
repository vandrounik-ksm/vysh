import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/platform/capabilities.dart';
import '../../infra/platform/font_files.dart';
import '../settings/terminal_font.dart';
import 'settings_controller.dart';

export '../../domain/services/font_info.dart' show AddFontError, AddFontException;
export '../../infra/platform/font_files.dart' show UserFont;

/// Моноширинные шрифты системы. Читаются один раз, когда понадобились
/// (открыли настройки), а не при запуске.
final systemFontsProvider = FutureProvider<List<String>>((ref) async {
  if (!PlatformCapabilities.systemFontList) return const [];
  try {
    return await FontFiles.systemMonospace();
  } catch (_) {
    return const [];
  }
});

/// Свои шрифты из папки профиля `fonts/`.
final userFontsProvider = NotifierProvider<UserFontsController, List<UserFont>>(
  UserFontsController.new,
);

class UserFontsController extends Notifier<List<UserFont>> {
  @override
  List<UserFont> build() => FontFiles.listUser();

  /// Копирует файл в профиль, загружает и выбирает его.
  /// Бросает [AddFontException].
  Future<UserFont> add(String path) async {
    final font = await FontFiles.addUser(path);
    state = FontFiles.listUser();
    ref.read(settingsProvider.notifier).setTerminalFont(TerminalFont.file(font.fileName));
    return font;
  }

  /// Выбрать уже добавленный шрифт: сначала загрузить, потом переключить,
  /// иначе терминал успеет измерить ячейки запасным шрифтом.
  Future<void> select(UserFont font) async {
    await FontFiles.load(font);
    ref.read(settingsProvider.notifier).setTerminalFont(TerminalFont.file(font.fileName));
  }

  Future<void> remove(UserFont font) async {
    final settings = ref.read(settingsProvider.notifier);
    if (TerminalFont.fileName(ref.read(settingsProvider).terminalFont) == font.fileName) {
      settings.setTerminalFont('');
    }
    await FontFiles.deleteUser(font.fileName);
    state = FontFiles.listUser();
  }
}
