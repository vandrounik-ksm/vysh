import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/app/sftp/sftp_directory.dart';
import 'package:vysh/domain/ports/sftp.dart';

/// SFTP, у которого ответы на list() приходят тогда, когда скажет тест.
class _ManualSftp implements SftpSession {
  final pending = <String, Completer<List<RemoteEntry>>>{};

  @override
  Future<List<RemoteEntry>> list(String path) => (pending[path] = Completer()).future;

  @override
  Future<String> home() async => '/home/u';

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

RemoteEntry _file(String dir, String name) =>
    RemoteEntry(name: name, path: '$dir/$name', isDir: false);

void main() {
  test('F16: поздний ответ на старый запрос не меняет открытую папку', () async {
    final sftp = _ManualSftp();
    final dir = SftpDirectory(() async => sftp);

    final a = dir.open('/a');
    final b = dir.open('/b');
    await Future<void>.delayed(Duration.zero);

    sftp.pending['/b']!.complete([_file('/b', 'from-b')]);
    await b;
    sftp.pending['/a']!.complete([_file('/a', 'from-a')]);
    await a;

    expect(dir.cwd, '/b');
    expect(dir.entries.single.name, 'from-b');
    expect(dir.loading, isFalse);
  });

  test('папки сначала, затем по имени без учёта регистра', () async {
    final sftp = _ManualSftp();
    final dir = SftpDirectory(() async => sftp);
    final f = dir.open('/x');
    await Future<void>.delayed(Duration.zero);
    sftp.pending['/x']!.complete([
      _file('/x', 'b.txt'),
      const RemoteEntry(name: 'Zdir', path: '/x/Zdir', isDir: true),
      _file('/x', 'A.txt'),
    ]);
    await f;
    expect(dir.entries.map((e) => e.name), ['Zdir', 'A.txt', 'b.txt']);
  });

  test('ошибка сохраняется как объект, прежняя папка остаётся', () async {
    final sftp = _ManualSftp();
    final dir = SftpDirectory(() async => sftp);
    final ok = dir.open('/ok');
    await Future<void>.delayed(Duration.zero);
    sftp.pending['/ok']!.complete(const []);
    await ok;

    final bad = dir.open('/bad');
    await Future<void>.delayed(Duration.zero);
    sftp.pending['/bad']!.completeError(const SftpFailure(SftpFailureCode.permissionDenied));
    await bad;

    expect(dir.cwd, '/ok');
    expect(dir.requestedPath, '/bad');
    expect(dir.error, isA<SftpFailure>());
  });

  test('после dispose ответы игнорируются', () async {
    final sftp = _ManualSftp();
    final dir = SftpDirectory(() async => sftp);
    final f = dir.open('/x');
    await Future<void>.delayed(Duration.zero);
    dir.dispose();
    sftp.pending['/x']!.complete(const []);
    await f; // не бросает notifyListeners после dispose
    expect(dir.entries, isEmpty);
    expect(dir.cwd, isNull);
  });
}
