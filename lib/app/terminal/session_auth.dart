import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/models/host.dart';
import '../../domain/ports/secret_store.dart';
import '../../domain/ports/session_prompts.dart';
import '../../domain/ports/ssh_transport.dart';
import '../../domain/services/known_hosts.dart';
import '../../infra/platform/local_files.dart';
import '../../l10n/app_strings.dart';

/// Сообщение для журнала или терминала на языке интерфейса.
typedef SessionText = String Function(AppStrings s);

/// Вход на сервер для одной попытки подключения сессии: ключи, пароль
/// (из памяти, хранилища или диалога), keyboard-interactive, проверка ключа
/// сервера, до трёх попыток с повторным запросом пароля.
class SessionAuthenticator {
  SessionAuthenticator({
    required this.host,
    required this.connector,
    required this.prompts,
    required this.secrets,
    required this.knownHosts,
    required this.keepAlive,
    required String? memPassword,
    required this.log,
    required this.info,
    required this.error,
    required this.banner,
  }) : _memPassword = memPassword;

  final Host host;
  final SshConnector connector;
  final SessionPrompts prompts;
  final SecretStore secrets;
  final KnownHosts knownHosts;
  final Duration keepAlive;
  final void Function(SessionText text, {bool debug, bool error}) log;
  final void Function(SessionText text) info;
  final void Function(SessionText text) error;
  final void Function(String banner) banner;

  /// Пароль, введённый в этой сессии раньше; после неудачного входа
  /// сбрасывается. После успешного входа - пароль, которым вошли.
  String? get memPassword => _memPassword;
  String? _memPassword;

  Future<SshTransport> connect(Future<void> abort) => _connectWithRetries(abort);

  Future<SshTransport> _connectWithRetries(Future<void> abort) async {
    var keys = await _loadKeys();

    String? password;
    var passwordFromStore = false;
    var rememberPassword = false;
    var cancelled = false;

    if (host.auth == AuthMethod.password) {
      password = _memPassword;
      if (password == null) {
        password = await _readSecret(passwordKey(host.id));
        passwordFromStore = password != null;
      }
    }

    Future<String?> providePassword(bool retry) async {
      if (password != null) return password;
      final answer = await prompts.askPassword(host, retry: retry);
      if (answer == null) {
        cancelled = true;
        return null;
      }
      password = answer.value;
      rememberPassword = answer.remember;
      return password;
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final retry = attempt > 0;
      try {
        final transport = await connector.connect(
          SshConnectRequest(
            address: host.address,
            port: host.port,
            username: host.username,
            keys: keys,
            keepAliveInterval: keepAlive,
            cancelled: abort,
            password: host.auth == AuthMethod.password
                ? () => providePassword(retry)
                : null,
            interactive: (name, instruction, list) async {
              // Обычный «Password:» через keyboard-interactive - отвечаем паролем.
              // Одноразовые коды и прочие вопросы сервера показываем как есть:
              // пароль туда отправлять нельзя.
              if (host.auth == AuthMethod.password &&
                  list.length == 1 &&
                  !list.first.echo &&
                  isPasswordPrompt(list.first.text)) {
                final p = await providePassword(retry);
                return p == null ? null : [p];
              }
              final answers = await prompts.askInteractive(
                host,
                name,
                instruction,
                list,
              );
              if (answers == null) cancelled = true;
              return answers;
            },
            verifyHostKey: _verifyHostKey,
            onBanner: banner,
            onLog: (e) => log((s) => s.sshStep(e), debug: e.debug, error: e.error),
          ),
        );

        _memPassword = password;
        if (rememberPassword && password != null) {
          try {
            await secrets.write(passwordKey(host.id), password!);
          } catch (_) {
            info((s) => s.passwordNotSaved);
          }
        }
        return transport;
      } on SshFailure catch (e) {
        if (cancelled) {
          throw const SshFailure(SshError.cancelled);
        }
        switch (e.kind) {
          case SshFailureKind.auth when host.auth == AuthMethod.password:
            if (passwordFromStore) {
              passwordFromStore = false;
              await _deleteSecret(passwordKey(host.id));
            }
            password = null;
            _memPassword = null;
            error((s) => s.logWrongPassword);
          case SshFailureKind.keyPassphrase:
            await _deleteSecret(passphraseKey(host.id));
            error((s) => s.sshFailure(e));
            keys = await _loadKeys(retry: true);
          default:
            rethrow;
        }
      }
    }
    throw const SshFailure(SshError.tooManyAttempts);
  }

  /// Сохранённый секрет; если хранилище недоступно - говорим об этом
  /// в терминале и спрашиваем пользователя, как будто секрета нет.
  Future<String?> _readSecret(String key) async {
    try {
      return await secrets.read(key);
    } on SecretStoreUnavailable catch (e) {
      log((s) => s.keyringUnavailable(e.detail), error: true);
      info((s) => s.keyringUnavailable(e.detail));
      return null;
    }
  }

  Future<void> _deleteSecret(String key) async {
    try {
      await secrets.delete(key);
    } catch (_) {
      info((s) => s.secretNotDeleted);
    }
  }

  Future<bool> _verifyHostKey(String type, String fingerprint) async {
    final known = knownHosts.lookup(host.address, host.port);
    if (known != null && known.fingerprint == fingerprint) return true;

    final ok = await prompts.confirmHostKey(
      host,
      type: type,
      fingerprint: fingerprint,
      previous: known?.fingerprint,
    );
    if (ok) knownHosts.remember(host.address, host.port, type, fingerprint);
    return ok;
  }

  Future<List<SshKeySource>> _loadKeys({bool retry = false}) async {
    switch (host.auth) {
      case AuthMethod.password:
        return const [];

      case AuthMethod.key:
        final raw = (host.keyPath?.trim().isNotEmpty ?? false)
            ? host.keyPath!.trim()
            : '~/.ssh/id_ed25519';
        final path = expandHome(raw);
        final file = File(path);
        if (!await file.exists()) {
          throw SshFailure(SshError.keyFileMissing, {'path': path});
        }
        final pem = await file.readAsString();
        if (pem.contains('PuTTY-User-Key-File')) {
          throw const SshFailure(SshError.puttyKey);
        }
        String? passphrase;
        if (connector.isKeyEncrypted(pem)) {
          passphrase = retry
              ? null
              : await _readSecret(passphraseKey(host.id));
          if (passphrase == null) {
            final answer = await prompts.askPassphrase(host, raw, retry: retry);
            if (answer == null) {
              throw const SshFailure(SshError.cancelled);
            }
            passphrase = answer.value;
            if (answer.remember) {
              try {
                await secrets.write(passphraseKey(host.id), passphrase);
              } catch (_) {}
            }
          }
        }
        return [SshKeySource(label: raw, pem: pem, passphrase: passphrase)];

      case AuthMethod.agent:
        // Пока без ssh-agent: берём стандартные незашифрованные ключи из ~/.ssh.
        final result = <SshKeySource>[];
        for (final name in const ['id_ed25519', 'id_ecdsa', 'id_rsa']) {
          final file = File(expandHome('~/.ssh/$name'));
          if (!await file.exists()) continue;
          final pem = await file.readAsString();
          if (connector.isKeyEncrypted(pem)) continue;
          result.add(SshKeySource(label: '~/.ssh/$name', pem: pem));
        }
        if (result.isEmpty) {
          throw const SshFailure(SshError.noDefaultKeys);
        }
        return result;
    }
  }
}

/// Похож ли единственный скрытый вопрос keyboard-interactive на запрос
/// пароля. Одноразовые коды (Verification code, OTP, token, PIN) - нет:
/// на них отвечает пользователь, сохранённый пароль туда не отправляем.
bool isPasswordPrompt(String text) {
  final t = text.toLowerCase();
  if (RegExp(r'code|otp|token|verif|one[- ]?time|2fa|mfa|totp|pin\b|passcode|код|токен')
      .hasMatch(t)) {
    return false;
  }
  return RegExp(r'password|passwort|mot de passe|contrase|пароль').hasMatch(t);
}

/// `~/...` → домашняя папка (на Windows - %USERPROFILE%).
/// На macOS под App Sandbox - настоящий дом пользователя, не контейнер:
/// ключи `~/.ssh/...` лежат именно там, и чтение разрешено песочницей.
String expandHome(String path) {
  if (!path.startsWith('~')) return path;
  if (kIsWeb) return path;
  try {
    final env = Platform.environment;
    final String home;
    if (!kIsWeb && Platform.isMacOS) {
      home = LocalFiles.macRealHome() ?? env['HOME'] ?? '';
    } else {
      home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    }
    final rest = path.substring(1).replaceAll('/', Platform.pathSeparator);
    return '$home$rest';
  } catch (_) {
    return path;
  }
}
