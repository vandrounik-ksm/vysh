part of 'app_strings.dart';

/// Подключение: ошибки SSH, журнал, сообщения в терминале, диалоги входа.
extension ConnectionStrings on AppStrings {
  // ─── Ошибки SSH ───────────────────────────────────────────────────

  String sshFailure(SshFailure f) {
    String a(String k) => f.args[k] ?? '';
    final detail = f.args['detail'];
    return switch (f.error) {
      SshError.dnsFailed => isRu
          ? 'Не удалось найти хост «${a('host')}»: имя не разрешается через DNS'
          : 'Host «${a('host')}» not found: the name does not resolve via DNS',
      SshError.tcpTimeout =>
        isRu ? 'Нет ответа от ${a('target')} (таймаут)' : 'No response from ${a('target')} (timeout)',
      SshError.tcpFailed => isRu
          ? 'Не удалось подключиться к ${a('target')}: ${a('detail')}'
          : 'Could not connect to ${a('target')}: ${a('detail')}',
      SshError.authTimeout => isRu
          ? 'Сервер не ответил при входе (${a('seconds')} с)'
          : 'The server did not respond during login (${a('seconds')} s)',
      SshError.abortedBeforeAuth => isRu
          ? 'Соединение прервано до входа${detail == null ? '' : ': $detail'}'
          : 'Connection closed before login${detail == null ? '' : ': $detail'}',
      SshError.connectionLost => isRu ? 'Соединение с сервером потеряно' : 'Connection to the server lost',
      SshError.authRejected =>
        isRu ? 'Сервер отклонил логин, пароль или ключ' : 'The server rejected the login, password or key',
      SshError.tooManyAttempts =>
        isRu ? 'Не удалось войти после трёх попыток.' : 'Login failed after three attempts.',
      SshError.hostKeyRejected => isRu ? 'Ключ сервера отклонён' : 'Host key rejected',
      SshError.wrongPassphrase => isRu
          ? 'Неверная парольная фраза для ключа ${a('key')}'
          : 'Wrong passphrase for key ${a('key')}',
      SshError.passphraseRequired => isRu
          ? 'Для ключа ${a('key')} нужна парольная фраза'
          : 'Key ${a('key')} needs a passphrase',
      SshError.keyUnreadable => isRu
          ? 'Не удалось прочитать ключ ${a('key')}: ${a('detail')}'
          : 'Could not read key ${a('key')}: ${a('detail')}',
      SshError.keyFileMissing =>
        isRu ? 'Файл ключа не найден: ${a('path')}' : 'Key file not found: ${a('path')}',
      SshError.puttyKey => isRu
          ? 'Ключи PuTTY (.ppk) пока не поддерживаются, экспортируйте ключ в формат OpenSSH в PuTTYgen.'
          : 'PuTTY keys (.ppk) are not supported yet; export the key to OpenSSH format in PuTTYgen.',
      SshError.noDefaultKeys => isRu
          ? 'В ~/.ssh не найдено незашифрованных ключей (id_ed25519, id_ecdsa, id_rsa).'
          : 'No unencrypted keys found in ~/.ssh (id_ed25519, id_ecdsa, id_rsa).',
      SshError.cancelled => isRu ? 'Отменено' : 'Cancelled',
      SshError.shellFailed => isRu
          ? 'Сервер не открыл оболочку: ${a('detail')}'
          : 'The server did not open a shell: ${a('detail')}',
      SshError.protocol => isRu ? 'Ошибка SSH: ${a('detail')}' : 'SSH error: ${a('detail')}',
      SshError.unexpected =>
        isRu ? 'Неожиданная ошибка: ${a('detail')}' : 'Unexpected error: ${a('detail')}',
    };
  }

  // ─── Журнал подключения ──────────────────────────────────────────

  String sshStep(SshLogEvent e) {
    String a(String k) => e.args[k] ?? '';
    return switch (e.step) {
      SshStep.key => isRu ? 'Ключ: ${a('key')}' : 'Key: ${a('key')}',
      SshStep.dnsLookup =>
        isRu ? 'Поиск адреса «${a('host')}» (DNS)…' : 'Resolving «${a('host')}» (DNS)…',
      SshStep.dnsResult => 'DNS: ${a('addresses')}',
      SshStep.dnsError => isRu ? 'DNS: ошибка: ${a('detail')}' : 'DNS: error: ${a('detail')}',
      SshStep.tcpConnect => isRu
          ? 'TCP-подключение к ${a('address')}:${a('port')}…'
          : 'TCP connection to ${a('address')}:${a('port')}…',
      SshStep.tcpConnected => isRu
          ? 'TCP-соединение с ${a('address')} установлено за ${a('ms')} ms'
          : 'TCP connection to ${a('address')} established in ${a('ms')} ms',
      SshStep.tcpError => isRu
          ? 'TCP: ${a('address')}: ошибка: ${a('detail')}'
          : 'TCP: ${a('address')}: error: ${a('detail')}',
      SshStep.serverSilent => isRu
          ? 'Сервер не ответил за ${a('seconds')} с'
          : 'The server did not respond in ${a('seconds')} s',
      SshStep.passwordAuth =>
        isRu ? 'Вход по паролю для ${a('user')}…' : 'Password login for ${a('user')}…',
      SshStep.keyboardInteractive => 'keyboard-interactive: ${a('prompts')}',
      SshStep.serverVersion => isRu ? 'Сервер: ${a('version')}' : 'Server: ${a('version')}',
      SshStep.hostKey => isRu
          ? 'Ключ сервера: ${a('type')} ${a('fingerprint')}'
          : 'Host key: ${a('type')} ${a('fingerprint')}',
      SshStep.hostKeyAccepted => isRu ? 'Ключ сервера принят' : 'Host key accepted',
      SshStep.hostKeyRejected => isRu ? 'Ключ сервера отклонён' : 'Host key rejected',
      SshStep.authenticated => isRu ? 'Вход выполнен' : 'Logged in',
      SshStep.authFailed =>
        isRu ? 'Аутентификация: ${a('detail')}' : 'Authentication: ${a('detail')}',
      SshStep.aborted => isRu ? 'Прервано: ${a('detail')}' : 'Aborted: ${a('detail')}',
      SshStep.sshError => isRu ? 'Ошибка SSH: ${a('detail')}' : 'SSH error: ${a('detail')}',
      SshStep.debug => a('text'),
    };
  }

  String logConnecting(String address, String auth) =>
      isRu ? 'Подключение к $address ($auth)' : 'Connecting to $address ($auth)';
  String get logWrongPassword => isRu ? 'Неверный логин или пароль.' : 'Wrong login or password.';
  String get logConnectionLost => isRu ? 'Соединение потеряно.' : 'Connection lost.';

  // ─── Сообщения сессии в терминале ────────────────────────────────

  String terminalConnecting(String address) =>
      isRu ? 'Подключение к $address…' : 'Connecting to $address…';
  String get terminalCancelled => isRu ? 'Подключение отменено.' : 'Connection cancelled.';
  String get terminalSessionEnded => isRu ? 'Сессия завершена.' : 'Session ended.';
  String get terminalPressEnter =>
      isRu ? 'Нажмите Enter, чтобы переподключиться.' : 'Press Enter to reconnect.';
  String get terminalPressReconnect => isRu
      ? 'Нажмите «Переподключить», чтобы восстановить связь.'
      : 'Tap «Reconnect» to restore the connection.';
  String get passwordNotSaved => isRu
      ? 'Не удалось сохранить пароль: системное хранилище недоступно.'
      : 'Could not save the password: the system keyring is unavailable.';
  String get secretNotDeleted => isRu
      ? 'Не удалось удалить неверный секрет: системное хранилище недоступно.'
      : 'Could not delete the wrong secret: the system keyring is unavailable.';
  String keyringUnavailable(String detail) => isRu
      ? 'Системное хранилище паролей недоступно ($detail), пароль будет запрошен.'
      : 'The system keyring is unavailable ($detail); you will be asked for the password.';
  String get noServerConnection => isRu ? 'Нет соединения с сервером' : 'No connection to the server';

  // ─── Диалоги подключения ─────────────────────────────────────────

  String get hostKeyChangedTitle => isRu ? 'Ключ сервера изменился!' : 'Host key changed!';
  String get hostKeyNewTitle => isRu ? 'Новый сервер' : 'New server';
  String hostKeyChangedText(String target) => isRu
      ? 'Сервер $target предъявил другой ключ. Так бывает после переустановки системы, '
          'но может означать и перехват соединения. Подключайтесь, только если уверены.'
      : 'Server $target presented a different key. This happens after a system reinstall, '
          'but it may also mean the connection is being intercepted. Connect only if you are sure.';
  String hostKeyNewText(String target) => isRu
      ? 'Подключение к $target впервые. Проверьте отпечаток ключа, если есть такая возможность.'
      : 'First connection to $target. Check the key fingerprint if you can.';
  String get fingerprintWas => isRu ? 'было:  ' : 'was:  ';
  String get fingerprintNow => isRu ? 'стало: ' : 'now:  ';
  String get connectAnyway => isRu ? 'Всё равно подключиться' : 'Connect anyway';
  String get trustAndConnect => isRu ? 'Доверять и подключиться' : 'Trust and connect';
  String get passwordTitle => isRu ? 'Пароль' : 'Password';
  String get wrongPasswordRetry =>
      isRu ? 'Неверный пароль, попробуйте ещё раз' : 'Wrong password, try again';
  String get passphraseTitle => isRu ? 'Парольная фраза ключа' : 'Key passphrase';
  String get passphraseLabel => isRu ? 'Парольная фраза' : 'Passphrase';
  String get wrongPassphrase => isRu ? 'Неверная парольная фраза' : 'Wrong passphrase';
  String get show => isRu ? 'Показать' : 'Show';
  String get hide => isRu ? 'Скрыть' : 'Hide';
  String get saveInKeyring =>
      isRu ? 'Сохранить в системном хранилище' : 'Save in the system keyring';
  String get connect => isRu ? 'Подключиться' : 'Connect';
  String get continueAction => isRu ? 'Продолжить' : 'Continue';
}
