part of 'app_strings.dart';

/// Хосты (массовые действия, редактор) и оболочка окна.
extension HostsStrings on AppStrings {
  String openTabsTitle(int n) => isRu ? 'Открыть $n вкладок?' : 'Open $n tabs?';
  String get openTabsDesc =>
      isRu ? 'Каждый хост откроется в отдельной вкладке.' : 'Each host opens in its own tab.';
  String deleteHostsTitle(int n) => n == 1
      ? (isRu ? 'Удалить хост?' : 'Delete host?')
      : (isRu ? 'Удалить $n хостов?' : 'Delete $n hosts?');
  String deleteHostsDesc(List<String> names) {
    final shown = names.take(8).join(', ');
    final more = names.length > 8
        ? (isRu ? ' и ещё ${names.length - 8}' : ' and ${names.length - 8} more')
        : '';
    return isRu
        ? '$shown$more.\nСохранённые пароли этих хостов тоже будут удалены.'
        : '$shown$more.\nSaved passwords of these hosts will be deleted too.';
  }

  String hostsDeleted(int n) =>
      n == 1 ? (isRu ? 'Хост удалён' : 'Host deleted') : (isRu ? 'Удалено хостов: $n' : 'Hosts deleted: $n');
  String connectAll(int n) => n == 1
      ? connect
      : (isRu ? 'Подключиться ко всем' : 'Connect to all');
  String connectAllCount(int n) =>
      n == 1 ? connect : (isRu ? 'Подключиться ко всем ($n)' : 'Connect to all ($n)');
  String get selectGroup => isRu ? 'Выбрать группу' : 'Select group';
  String get deselectGroup => isRu ? 'Снять выбор с группы' : 'Deselect group';
  String get groupActions => isRu ? 'Действия с группой' : 'Group actions';
  String get deselectAll => isRu ? 'Снять выбор' : 'Deselect';
  String get selectAllInGroup => isRu ? 'Выбрать все в группе' : 'Select all in group';
  String get deleteGroup => isRu ? 'Удалить группу…' : 'Delete group…';
  String get clearSelectionEsc => isRu ? 'Снять выбор (Esc)' : 'Clear selection (Esc)';
  String selectedCount(int n) => isRu ? 'Выбрано: $n' : 'Selected: $n';
  String get selectEverything => isRu ? 'Выбрать все' : 'Select all';

  // Редактор хоста.
  String copyOf(String title) => isRu ? '$title (копия)' : '$title (copy)';
  String get sectionConnection => isRu ? 'Подключение' : 'Connection';
  String get sectionListAppearance => isRu ? 'Как показывать в списке' : 'List appearance';
  String get addressHintFull =>
      isRu ? '10.0.0.1, example.com или user@host:port' : '10.0.0.1, example.com or user@host:port';
  String get authAuto => isRu ? 'Авто' : 'Auto';
  String get passwordSavedHelper =>
      isRu ? 'Сохранён. Пустое поле его не меняет' : 'Saved. Leave empty to keep it';
  String get defaultKeysNote => isRu
      ? 'Стандартные ключи из ~/.ssh: id_ed25519, id_ecdsa, id_rsa'
      : 'Standard keys from ~/.ssh: id_ed25519, id_ecdsa, id_rsa';
  String keepAliveMinutes(int seconds) => isRu
      ? '$seconds секунд (${seconds ~/ 60} мин)'
      : '$seconds seconds (${seconds ~/ 60} min)';
  String get saveAndConnect => isRu ? 'Сохранить и подключиться' : 'Save & connect';
  String get choose => isRu ? 'Выбрать' : 'Choose';
  String get passwordNotDeleted => isRu
      ? 'Не удалось удалить сохранённый пароль: системное хранилище недоступно'
      : 'Could not delete the saved password: the system keyring is unavailable';
  String get passwordNotSavedShort => isRu
      ? 'Не удалось сохранить пароль: системное хранилище недоступно'
      : 'Could not save the password: the system keyring is unavailable';

  // Оболочка окна.
  String get closeWithShortcut => isRu ? 'Закрыть (Ctrl+Shift+W)' : 'Close (Ctrl+Shift+W)';
  String get minimize => isRu ? 'Свернуть' : 'Minimize';
  String get restore => isRu ? 'Восстановить' : 'Restore';
  String get maximize => isRu ? 'Развернуть' : 'Maximize';
  String get statusClosedShort => isRu ? 'Закрыто' : 'Closed';
  String memoryUsage(int mb, {required bool debug}) =>
      isRu ? 'Память: $mb МБ${debug ? ' (debug)' : ''}' : 'Memory: $mb MB${debug ? ' (debug)' : ''}';
  String get eofExit => isRu ? 'EOF / Выход' : 'EOF / Exit';

  /// Названия встроенных акцентов (в порядке [hostColors]/пресетов темы).
  List<String> get accentNames => isRu
      ? const ['Фиалка', 'Океан', 'Бирюза', 'Мята', 'Лайм', 'Янтарь', 'Коралл', 'Сакура', 'Графит']
      : const ['Violet', 'Ocean', 'Teal', 'Mint', 'Lime', 'Amber', 'Coral', 'Sakura', 'Graphite'];
}
