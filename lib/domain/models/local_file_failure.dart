/// Что не получилось с локальным файлом; текст собирает `l10n`.
enum LocalFileError {
  /// Файл не сохранился в общую папку Download (Android). args: detail.
  publishFailed,

  /// Android 9-: пользователь не дал разрешение на запись в Download.
  storagePermissionDenied,

  /// Имя файла с сервера нельзя использовать локально. args: name.
  badRemoteName,

  /// Системная программа не открыла файл. args: detail.
  openFailed,
}

class LocalFileFailure implements Exception {
  const LocalFileFailure(this.error, [this.args = const {}]);

  final LocalFileError error;
  final Map<String, String> args;

  @override
  String toString() => 'LocalFileFailure(${error.name}, $args)';
}
