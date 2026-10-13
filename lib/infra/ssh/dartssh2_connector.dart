import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../domain/ports/sftp.dart';
import '../../domain/ports/ssh_transport.dart';
import '../platform/net_resolve.dart';
import 'dartssh2_sftp.dart';

/// SSH на чистом Dart (dartssh2).
class DartSsh2Connector implements SshConnector {
  const DartSsh2Connector();

  @override
  bool isKeyEncrypted(String pem) {
    try {
      return SSHKeyPair.isEncryptedPem(pem);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SshTransport> connect(SshConnectRequest r) async {
    void log(SshStep step, [Map<String, String> args = const {}]) =>
        r.onLog?.call(SshLogEvent(step, args));

    // Отмена (закрыли вкладку): обрываем то, что сейчас идёт, - TCP-попытку
    // или SSH-клиент - не дожидаясь таймаутов.
    var cancelled = false;
    final onCancel = <void Function()>{};
    r.cancelled?.then((_) {
      cancelled = true;
      for (final f in [...onCancel]) {
        f();
      }
    });
    const cancelledFailure = SshFailure(SshError.cancelled);
    void checkCancelled() {
      if (cancelled) throw cancelledFailure;
    }

    final identities = <SSHKeyPair>[];
    for (final key in r.keys) {
      log(SshStep.key, {'key': key.label});
      identities.addAll(await _parseKey(key));
    }
    checkCancelled();

    // DNS отдельно - чтобы в логе было видно, на каком шаге проблема.
    // Порядок адресов общий с проверкой доступности (IPv4 первым).
    final List<InternetAddress> targets;
    final literal = InternetAddress.tryParse(r.address) != null;
    if (!literal) log(SshStep.dnsLookup, {'host': r.address});
    try {
      targets = await resolveHost(r.address, timeout: r.timeout);
      if (!literal) log(SshStep.dnsResult, {'addresses': targets.map((a) => a.address).join(', ')});
    } catch (e) {
      log(SshStep.dnsError, {'detail': '$e'});
      checkCancelled();
      throw SshFailure(SshError.dnsFailed, {'host': r.address});
    }
    checkCancelled();

    // Пробуем адреса по очереди: сломанный IPv6 или один мёртвый
    // A-адрес не должен мешать подключиться по остальным.
    Socket? raw;
    Object? lastError;
    for (final addr in targets.take(maxAddressAttempts)) {
      log(SshStep.tcpConnect, {'address': addr.address, 'port': '${r.port}'});
      final sw = Stopwatch()..start();
      ConnectionTask<Socket>? task;
      void abort() => task?.cancel();
      onCancel.add(abort);
      try {
        task = await Socket.startConnect(addr, r.port);
        raw = await task.socket.timeout(r.timeout, onTimeout: () {
          task?.cancel();
          throw TimeoutException('TCP', r.timeout);
        });
        log(SshStep.tcpConnected, {'address': addr.address, 'ms': '${sw.elapsedMilliseconds}'});
        break;
      } catch (e) {
        checkCancelled();
        log(SshStep.tcpError, {'address': addr.address, 'detail': '$e'});
        lastError = e;
      } finally {
        onCancel.remove(abort);
      }
    }
    if (raw == null) {
      throw _networkFailure(lastError, r);
    }
    if (cancelled) {
      raw.destroy();
      throw cancelledFailure;
    }
    final SSHSocket socket = _NativeSshSocket(raw);

    var hostKeyRejected = false;
    late final SSHClient client;

    // Сторож обмена ключами и входа: сервер, замолчавший на этом этапе,
    // не должен оставлять вкладку в «Подключение…» навсегда. Пока ждём
    // пользователя (ключ сервера, пароль, одноразовый код), сторож стоит.
    var waitingForUser = 0;
    var authDone = false;
    var timedOut = false;
    Timer? watchdog;
    void arm() {
      watchdog?.cancel();
      if (authDone || waitingForUser > 0) return;
      watchdog = Timer(r.authTimeout, () {
        timedOut = true;
        log(SshStep.serverSilent, {'seconds': '${r.authTimeout.inSeconds}'});
        client.close();
        socket.destroy();
      });
    }

    Future<T> askUser<T>(Future<T> Function() ask) async {
      waitingForUser++;
      watchdog?.cancel();
      try {
        return await ask();
      } finally {
        waitingForUser--;
        arm();
      }
    }

    client = SSHClient(
      socket,
      username: r.username,
      identities: identities.isEmpty ? null : identities,
      onPasswordRequest: r.password == null
          ? null
          : () {
              log(SshStep.passwordAuth, {'user': r.username});
              return askUser(r.password!);
            },
      onUserInfoRequest: r.interactive == null
          ? null
          : (req) {
              log(SshStep.keyboardInteractive,
                  {'prompts': req.prompts.map((p) => p.promptText.trim()).join(' | ')});
              return askUser(() => r.interactive!(req.name, req.instruction, [
                    for (final p in req.prompts) (text: p.promptText, echo: p.echo),
                  ]));
            },
      onVerifyHostKey: (type, fingerprint) async {
        final fp = utf8.decode(fingerprint);
        log(SshStep.serverVersion, {'version': client.remoteVersion ?? '?'});
        log(SshStep.hostKey, {'type': type, 'fingerprint': fp});
        final ok = await askUser(() => r.verifyHostKey(type, fp));
        log(ok ? SshStep.hostKeyAccepted : SshStep.hostKeyRejected);
        if (!ok) hostKeyRejected = true;
        return ok;
      },
      onUserauthBanner: r.onBanner,
      onAuthenticated: () => log(SshStep.authenticated),
      printDebug: (line) => log(SshStep.debug, {'text': line ?? ''}),
      keepAliveInterval: r.keepAliveInterval <= Duration.zero
          ? null
          : r.keepAliveInterval,
    );
    void closeClient() {
      client.close();
      socket.destroy();
    }

    onCancel.add(closeClient);
    arm();

    SshFailure failure(SshFailure f) {
      closeClient();
      if (cancelled) return cancelledFailure;
      if (timedOut) {
        return SshFailure(SshError.authTimeout, {'seconds': '${r.authTimeout.inSeconds}'});
      }
      if (hostKeyRejected) {
        return const SshFailure(SshError.hostKeyRejected);
      }
      return f;
    }

    try {
      await client.authenticated;
    } on SSHAuthFailError catch (e) {
      log(SshStep.authFailed, {'detail': e.message});
      throw failure(const SshFailure(SshError.authRejected));
    } on SSHAuthAbortError catch (e) {
      final reason = e.reason;
      log(SshStep.aborted, {'detail': reason == null ? e.message : '${e.message} ($reason)'});
      throw failure(SshFailure(SshError.abortedBeforeAuth, {if (reason != null) 'detail': '$reason'}));
    } on SSHError catch (e) {
      log(SshStep.sshError, {'detail': '$e'});
      throw failure(SshFailure(SshError.protocol, {'detail': '$e'}));
    } finally {
      authDone = true;
      watchdog?.cancel();
      onCancel.remove(closeClient);
    }
    if (cancelled) {
      closeClient();
      throw cancelledFailure;
    }

    return _Transport(client);
  }

  Future<List<SSHKeyPair>> _parseKey(SshKeySource key) async {
    List<SSHKeyPair> parse() => SSHKeyPair.fromPem(key.pem, key.passphrase);
    try {
      try {
        // Расшифровка ключа (bcrypt) может занять заметное время - в отдельном изоляте.
        return await Isolate.run(parse);
      } catch (_) {
        // Ошибки из изолята приходят «обёрнутыми» - повторяем здесь,
        // чтобы получить настоящий тип исключения.
        return parse();
      }
    } on SSHKeyDecryptError {
      throw SshFailure(SshError.wrongPassphrase, {'key': key.label});
    } on ArgumentError {
      throw SshFailure(SshError.passphraseRequired, {'key': key.label});
    } catch (e) {
      throw SshFailure(SshError.keyUnreadable, {'key': key.label, 'detail': '$e'});
    }
  }

  SshFailure _networkFailure(Object? e, SshConnectRequest r) {
    final target = '${r.address}:${r.port}';
    if (e is TimeoutException) return SshFailure(SshError.tcpTimeout, {'target': target});
    final detail = switch (e) {
      SocketException(:final osError?) => osError.message.trim(),
      SocketException(:final message) => message,
      null => '-',
      _ => '$e',
    };
    return SshFailure(SshError.tcpFailed, {'target': target, 'detail': detail});
  }
}

class _Transport implements SshTransport {
  _Transport(this._client);

  final SSHClient _client;

  @override
  Future<void> get done => _client.done.catchError((_) {});

  @override
  String? get serverVersion => _client.remoteVersion;

  @override
  Future<SshShell> openShell({required int columns, required int rows}) async {
    try {
      final session = await _client.shell(
        pty: SSHPtyConfig(width: columns, height: rows),
      );
      return _Shell(session);
    } on SSHError catch (e) {
      throw SshFailure(SshError.shellFailed, {'detail': '$e'});
    }
  }

  @override
  Future<String> exec(String command) async {
    final out = await _client.run(command, stderr: false);
    return utf8.decode(out, allowMalformed: true);
  }

  @override
  Future<SftpSession> openSftp() async {
    try {
      return DartSsh2Sftp(await _client.sftp());
    } on SSHError catch (e) {
      throw SftpFailure(SftpFailureCode.sftpUnavailable, {'detail': '$e'});
    }
  }

  @override
  Future<void> close() async {
    try {
      _client.close();
    } catch (_) {}
  }
}

class _Shell implements SshShell {
  _Shell(this._session) {
    var open = 2;
    void onDone() {
      if (--open == 0) _output.close();
    }

    _session.stdout.listen(_output.add, onError: (_) {}, onDone: onDone);
    _session.stderr.listen(_output.add, onError: (_) {}, onDone: onDone);
  }

  final SSHSession _session;
  final _output = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<void> get done => _session.done.catchError((_) {});

  @override
  void write(Uint8List data) {
    try {
      _session.write(data);
    } catch (_) {}
  }

  @override
  void resize(int columns, int rows) {
    if (columns <= 0 || rows <= 0) return;
    try {
      _session.resizeTerminal(columns, rows);
    } catch (_) {}
  }

  @override
  void close() {
    try {
      _session.close();
    } catch (_) {}
  }
}

class _NativeSshSocket implements SSHSocket {
  _NativeSshSocket(this._socket) {
    try {
      _socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
  }

  final Socket _socket;

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();

  @override
  Future<void> flush() => _socket.flush();
}
