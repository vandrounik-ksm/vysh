import 'dart:io';

/// Запись в удалённой папке.
class RemoteEntry {
  const RemoteEntry({
    required this.name,
    required this.path,
    required this.isDir,
    this.isLink = false,
    this.size = 0,
    this.modified,
    this.mode,
  });

  final String name;
  final String path;
  final bool isDir;
  final bool isLink;
  final int size;
  final DateTime? modified;

  /// Права (st_mode), если сервер их прислал.
  final int? mode;

  bool get isHidden => name.startsWith('.');

  /// Права в виде `rwxr-xr-x`.
  String get permissions {
    final m = mode;
    if (m == null) return '';
    const chars = 'rwxrwxrwx';
    final b = StringBuffer();
    for (var i = 0; i < 9; i++) {
      b.write((m & (1 << (8 - i))) != 0 ? chars[i] : '-');
    }
    return b.toString();
  }
}

/// Что именно не получилось. Код не разбирает текст сообщения, а текст для
/// пользователя собирает `l10n` по коду и [SftpFailure.args].
enum SftpFailureCode {
  noSuchFile,
  permissionDenied,

  /// args: path.
  notADirectory,

  /// args: path.
  isDirectory,
  exists,

  /// args: detail (может отсутствовать).
  failed,
  unsupported,

  /// Канал SFTP не ответил: на сервере, скорее всего, нет sftp-server.
  noSftpServer,

  /// args: detail.
  sftpUnavailable,
  noConnection,
  connectionClosed,

  /// args: detail.
  localFile,

  /// args: detail.
  connection,

  /// args: seconds.
  stalled,

  /// args: code (номер статуса SFTP), detail (может отсутствовать).
  other,
}

class SftpFailure implements Exception {
  const SftpFailure(this.code, [this.args = const {}]);
  final SftpFailureCode code;
  final Map<String, String> args;
  @override
  String toString() => args.isEmpty ? 'SftpFailure(${code.name})' : 'SftpFailure(${code.name}, $args)';
}

class TransferCancelled implements Exception {
  const TransferCancelled();
}

/// Флаг отмены передачи.
class CancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in _listeners) {
      l();
    }
  }

  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

typedef ProgressCallback = void Function(int bytesDone);

/// SFTP поверх уже открытого SSH-соединения.
abstract interface class SftpSession {
  /// Домашняя папка (абсолютный путь).
  Future<String> home();

  Future<List<RemoteEntry>> list(String path);

  Future<RemoteEntry> stat(String path);

  Future<void> mkdir(String path);
  Future<void> rename(String from, String to);
  Future<void> removeFile(String path);
  Future<void> removeDir(String path);
  Future<void> chmod(String path, int mode);

  /// Отмена прерывает передачу сразу, даже если сервер перестал присылать
  /// данные; долгое отсутствие данных считается ошибкой.
  Future<void> download(
    String remotePath,
    File local, {
    required CancelToken cancel,
    required ProgressCallback onProgress,
  });

  /// Загрузка без риска для существующего файла: данные пишутся во временный
  /// файл рядом и только после успеха заменяют [remotePath] (с сохранением
  /// прав прежнего файла). При ошибке или отмене прежний файл не тронут.
  Future<void> upload(
    File local,
    String remotePath, {
    required CancelToken cancel,
    required ProgressCallback onProgress,
  });

  Future<void> close();
}

/// Склейка POSIX-путей на сервере.
String remoteJoin(String dir, String name) =>
    dir.endsWith('/') ? '$dir$name' : '$dir/$name';

String remoteParent(String path) {
  if (path == '/' || path.isEmpty) return '/';
  final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  final i = trimmed.lastIndexOf('/');
  return i <= 0 ? '/' : trimmed.substring(0, i);
}

String remoteBasename(String path) {
  final trimmed = path.endsWith('/') && path.length > 1 ? path.substring(0, path.length - 1) : path;
  final i = trimmed.lastIndexOf('/');
  return i < 0 ? trimmed : trimmed.substring(i + 1);
}
