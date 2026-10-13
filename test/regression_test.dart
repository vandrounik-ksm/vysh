// Регрессии по docs/PROJECT_REVIEW.md: каждый тест - сценарий, который
// раньше воспроизводил дефект.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/domain/models/app_settings.dart';
import 'package:vysh/domain/models/external_colors.dart';
import 'package:vysh/domain/models/host.dart';
import 'package:vysh/domain/models/session_tab.dart';
import 'package:vysh/domain/ports/secret_store.dart';
import 'package:vysh/domain/ports/session_prompts.dart';
import 'package:vysh/domain/ports/sftp.dart';
import 'package:vysh/domain/ports/ssh_transport.dart';
import 'package:vysh/domain/services/known_hosts.dart';
import 'package:vysh/domain/services/terminal_session.dart';
import 'package:vysh/infra/platform/local_files.dart';
import 'package:vysh/infra/storage/app_paths.dart';
import 'package:vysh/infra/storage/json_store.dart';
import 'package:vysh/ui/terminal/selection_menu.dart';

const host = Host(id: 'test', label: '', address: 'test.invalid');

class _Secrets implements SecretStore {
  @override
  Future<String?> read(String key) async => 'stored-password';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _Prompts implements SessionPrompts {
  int interactiveCalls = 0;
  @override
  Future<bool> confirmHostKey(Host host,
          {required String type, required String fingerprint, String? previous}) async =>
      false;
  @override
  Future<SecretAnswer?> askPassword(Host host,
          {bool retry = false, bool canRemember = true}) async =>
      null;
  @override
  Future<SecretAnswer?> askPassphrase(Host host, String keyLabel, {bool retry = false}) async =>
      null;
  @override
  Future<List<String>?> askInteractive(
      Host host, String name, String instruction, List<SshPrompt> prompts) async {
    interactiveCalls++;
    return ['123456'];
  }
}

class _Connector implements SshConnector {
  _Connector(this.run);
  final Future<SshTransport> Function(SshConnectRequest) run;
  @override
  Future<SshTransport> connect(SshConnectRequest request) => run(request);
  @override
  bool isKeyEncrypted(String pem) => false;
}

class _Shell implements SshShell {
  bool closed = false;
  final end = Completer<void>();
  @override
  Future<void> get done => end.future;
  @override
  Stream<Uint8List> get output => const Stream.empty();
  @override
  void close() => closed = true;
  @override
  void resize(int columns, int rows) {}
  @override
  void write(Uint8List data) {}
}

class _Transport implements SshTransport {
  final pendingShell = Completer<SshShell>();
  final end = Completer<void>();
  bool opened = false;
  bool closed = false;
  @override
  Future<SshShell> openShell({required int columns, required int rows}) {
    opened = true;
    return pendingShell.future;
  }

  @override
  Future<void> close() async => closed = true;
  @override
  Future<void> get done => end.future;
  @override
  String? get serverVersion => 'test';
  @override
  Future<String> exec(String command) async => '';
  @override
  Future<SftpSession> openSftp() async => throw UnimplementedError();
}

TerminalSession _session(_Connector connector, _Prompts prompts, {String? password}) =>
    TerminalSession(
      host: host,
      connector: connector,
      prompts: prompts,
      secrets: _Secrets(),
      knownHosts: KnownHosts(),
      onStatus: (_) {},
      initialPassword: password,
    );

void main() {
  late Directory profile;

  setUpAll(() async {
    profile = await Directory.systemTemp.createTemp('vysh-test-profile-');
    AppPaths.configDirForTest = profile;
  });

  tearDownAll(() async {
    try {
      await profile.delete(recursive: true);
    } catch (_) {}
  });

  group('F01 JsonStore', () {
    test('запись заменяет файл и оставляет копию', () async {
      final store = JsonStore('f01.json');
      expect(await store.write({'v': 1}), isTrue);
      expect(await store.write({'v': 2}), isTrue);
      expect(store.readSync(), {'v': 2});
      expect(File('${store.file.path}.bak').readAsStringSync(), contains('1'));
      expect(File('${store.file.path}.tmp').existsSync(), isFalse);
    });

    test('без основного файла данные берутся из целого .tmp', () async {
      final store = JsonStore('f01b.json');
      File('${store.file.path}.tmp').writeAsStringSync('{"v": 3}');
      expect(store.readSync(), {'v': 3});
    });

    test('битый файл откладывается, данные из .bak', () async {
      final store = JsonStore('f01c.json');
      await store.write({'v': 1});
      await store.write({'v': 2});
      store.file.writeAsStringSync('{broken');
      expect(store.readSync(), {'v': 1});
      final corrupt = profile
          .listSync()
          .where((f) => f.path.contains('f01c.json.corrupt-'));
      expect(corrupt, isNotEmpty);
    });
  });

  group('F09 JSON с неверными типами', () {
    test('порт строкой читается, мусор даёт значения по умолчанию', () {
      expect(Host.fromJson({'address': 'a.example', 'port': '2222'}).port, 2222);
      final h = Host.fromJson({'address': 'a.example', 'port': [1], 'label': 5, 'color': 'x'});
      expect(h.port, 22);
      expect(h.label, '');
      expect(Host.fromJson({'address': 'a.example', 'port': 70000}).port, 22);
    });

    test('настройки с неверными типами не падают', () {
      final s = AppSettings.fromJson({'compact': 'yes', 'scrollbackLines': '5000', 'seedColor': true});
      expect(s.compact, isFalse);
      expect(s.scrollbackLines, 5000);
    });
  });

  group('F03/F08 локальные имена', () {
    test('имя с сервера не выводит за папку', () async {
      final dir = await Directory.systemTemp.createTemp('vysh-test-');
      try {
        for (final name in [r'..\escaped.txt', '../x', '..', '.', r'C:\x', 'a/b']) {
          final p = LocalFiles.uniquePath(dir.path, name);
          LocalFiles.releasePath(p);
          expect(LocalFiles.isWithin(dir.path, p), isTrue, reason: name);
        }
        if (Platform.isWindows) {
          expect(LocalFiles.safeName('CON.txt'), '_CON.txt');
          expect(LocalFiles.safeName('file:stream'), 'file_stream');
          expect(LocalFiles.safeName('trail. '), 'trail');
        }
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('два ожидающих скачивания получают разные пути', () async {
      final dir = await Directory.systemTemp.createTemp('vysh-test-');
      try {
        final a = LocalFiles.uniquePath(dir.path, 'same.txt');
        final b = LocalFiles.uniquePath(dir.path, 'same.txt');
        expect(a, isNot(b));
        LocalFiles.releasePath(a);
        LocalFiles.releasePath(b);
        Directory('${dir.path}${Platform.pathSeparator}folder').createSync();
        final c = LocalFiles.uniquePath(dir.path, 'folder');
        expect(c, endsWith('folder (1)'));
        LocalFiles.releasePath(c);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  test('F15 изменение только цвета текста терминала заметно', () {
    const a = ExternalColors(
        seed: Color(0xff123456), source: 't', terminalForeground: Color(0xffaaaaaa));
    const b = ExternalColors(
        seed: Color(0xff123456), source: 't', terminalForeground: Color(0xffbbbbbb));
    expect(a.sameAs(b), isFalse);
  });

  group('F18 защита вставки', () {
    test('завершающий Enter и одиночный CR требуют подтверждения', () {
      expect(PastePlan('ls').hasLineBreaks, isFalse);
      expect(PastePlan('rm -rf x\n').hasLineBreaks, isTrue);
      expect(PastePlan('rm -rf x\n').onlyTrailingEnter, isTrue);
      expect(PastePlan('a\rb').hasLineBreaks, isTrue);
      expect(PastePlan('a\rb').visibleLines, ['a', 'b']);
    });

    test('«одной строкой» не содержит ни CR, ни LF', () {
      expect(PastePlan('a\r\nb\rc\n').singleLine, 'a b c');
    });
  });

  group('F04 keyboard-interactive', () {
    test('распознаётся только запрос пароля', () {
      expect(isPasswordPrompt('Password: '), isTrue);
      expect(isPasswordPrompt('(root@srv) Password:'), isTrue);
      expect(isPasswordPrompt('Пароль:'), isTrue);
      expect(isPasswordPrompt('Verification code:'), isFalse);
      expect(isPasswordPrompt('One-time password (OATH) for root:'), isFalse);
      expect(isPasswordPrompt('Enter PIN:'), isFalse);
    });

    test('скрытый одноразовый код спрашивается у пользователя', () async {
      final prompts = _Prompts();
      List<String>? response;
      final session = _session(_Connector((r) async {
        response = await r.interactive!(
            'OTP', 'Enter one-time code', [(text: 'Verification code:', echo: false)]);
        throw const SshFailure(SshFailureKind.network, 'stop');
      }), prompts);
      try {
        await session.connect();
        expect(response, ['123456']);
        expect(prompts.interactiveCalls, 1);
      } finally {
        session.dispose();
      }
    });
  });

  group('F05 поколения подключения', () {
    test('оболочка, пришедшая после закрытия вкладки, закрывается', () async {
      final transport = _Transport();
      final shell = _Shell();
      final session = _session(_Connector((_) async => transport), _Prompts());
      final connecting = session.connect();
      await Future<void>.delayed(Duration.zero);
      expect(transport.opened, isTrue);
      session.dispose();
      transport.pendingShell.complete(shell);
      await connecting;
      expect(shell.closed, isTrue);
      expect(transport.closed, isTrue);
    });

    test('завершение старого соединения не трогает новое', () async {
      final first = _Transport()..pendingShell.complete(_Shell());
      final secondShell = _Shell();
      final second = _Transport()..pendingShell.complete(secondShell);
      var attempt = 0;
      final session =
          _session(_Connector((_) async => attempt++ == 0 ? first : second), _Prompts());
      try {
        await session.connect();
        await session.connect();
        expect(session.status, SessionStatus.ready);
        first.end.complete();
        await Future<void>.delayed(Duration.zero);
        expect(session.status, SessionStatus.ready);
        expect(secondShell.closed, isFalse);
      } finally {
        session.dispose();
      }
    });

    test('закрытие вкладки прерывает попытку подключения', () async {
      final started = Completer<void>();
      var cancelled = false;
      final session = _session(_Connector((r) async {
        started.complete();
        await r.cancelled;
        cancelled = true;
        throw const SshFailure(SshFailureKind.cancelled, 'Отменено');
      }), _Prompts());
      final connecting = session.connect();
      await started.future;
      session.dispose();
      await connecting;
      expect(cancelled, isTrue);
    });
  });

  test('F07 после смены адреса пароль прежнего сервера не используется', () async {
    final sent = <(String, String?)>[];
    final session = _session(
      _Connector((r) async {
        sent.add((r.address, await r.password!()));
        throw const SshFailure(SshFailureKind.network, 'stop');
      }),
      _Prompts(),
      password: 'old-host-password',
    );
    try {
      await session.connect();
      expect(sent.last, ('test.invalid', 'old-host-password'));
      session.host = const Host(id: 'test', label: '', address: 'another.invalid');
      await session.connect();
      expect(sent.last.$1, 'another.invalid');
      expect(sent.last.$2, isNot('old-host-password'));
    } finally {
      session.dispose();
    }
  });
}
