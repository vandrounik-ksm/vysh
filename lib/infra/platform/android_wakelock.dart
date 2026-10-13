import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/ports/background_sessions.dart';

/// Android: foreground-сервис с уведомлением держит процесс, пока есть
/// живые сессии (wake lock сервис берёт сам). На остальных платформах - ничего.
class AndroidBackgroundSessions implements BackgroundSessions {
  const AndroidBackgroundSessions();

  static const _channel = MethodChannel('uwu.vyto4ka.vysh/wakelock');

  static bool get _android {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  void active(String title) {
    if (!_android) return;
    _channel.invokeMethod<bool>('acquire', {'title': title}).catchError((_) => false);
  }

  @override
  void idle() {
    if (!_android) return;
    _channel.invokeMethod<bool>('release').catchError((_) => false);
  }
}
