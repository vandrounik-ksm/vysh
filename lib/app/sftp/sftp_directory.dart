import 'package:flutter/foundation.dart';

import '../../domain/ports/sftp.dart';

/// Содержимое одной удалённой папки для панели файлов: текущий путь,
/// список, загрузка и ошибка. Применяется только ответ на последний запрос:
/// если открыть папку A, затем B, а ответ A придёт позже, экран останется на B.
class SftpDirectory extends ChangeNotifier {
  SftpDirectory(this._sftp, {this.resetChannel});

  final Future<SftpSession> Function() _sftp;

  /// Сбросить SFTP-канал перед повторной попыткой после ошибки.
  final void Function()? resetChannel;

  /// Открытая папка; null - ещё ни одна не открыта.
  String? get cwd => _cwd;
  String? _cwd;

  /// Папки сначала, по имени без учёта регистра.
  List<RemoteEntry> get entries => _entries;
  List<RemoteEntry> _entries = const [];

  bool get loading => _loading;
  bool _loading = false;

  /// Ошибка последнего запроса (SftpFailure и т. п.); текст собирает UI.
  Object? get error => _error;
  Object? _error;

  /// Путь последнего запроса - чтобы показать его в поле при ошибке.
  String? get requestedPath => _requested;
  String? _requested;

  int _request = 0;
  bool _disposed = false;

  bool _stale(int request) => _disposed || request != _request;

  void _set(void Function() change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  /// Открыть домашнюю папку (после ошибки - через новый SFTP-канал).
  Future<void> home() async {
    if (_error != null) resetChannel?.call();
    final request = ++_request;
    _set(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = await (await _sftp()).home();
      if (_stale(request)) return;
      await open(path);
    } catch (e) {
      if (_stale(request)) return;
      _set(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> open(String path) async {
    final request = ++_request;
    _set(() {
      _loading = true;
      _error = null;
      _requested = path;
    });
    try {
      // Копия: порт не обещает изменяемый список.
      final list = [...await (await _sftp()).list(path)];
      list.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (_stale(request)) return;
      _set(() {
        _cwd = path;
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      if (_stale(request)) return;
      _set(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> refresh() async {
    final cwd = _cwd;
    if (cwd != null) await open(cwd);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
