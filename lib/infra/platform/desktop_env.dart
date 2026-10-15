import 'dart:io';

import 'package:flutter/foundation.dart';

/// Что за рабочее окружение вокруг нас.
class DesktopEnv {
  DesktopEnv._();

  static String get _desktop {
    if (kIsWeb) return '';
    try {
      return '${Platform.environment['XDG_CURRENT_DESKTOP'] ?? ''}:'
              '${Platform.environment['XDG_SESSION_DESKTOP'] ?? ''}:'
              '${Platform.environment['DESKTOP_SESSION'] ?? ''}'
          .toLowerCase();
    } catch (_) {
      return '';
    }
  }

  /// Тайлинговые WM: свой заголовок там не нужен, окна раскладывает WM.
  static bool get isTiling {
    if (kIsWeb) return false;
    try {
      if (!Platform.isLinux) return false;
      if (Platform.environment['HYPRLAND_INSTANCE_SIGNATURE'] != null) return true;
      if (Platform.environment['SWAYSOCK'] != null) return true;
      if (Platform.environment['NIRI_SOCKET'] != null) return true;
      const tiling = [
        'hyprland', 'sway', 'i3', 'niri', 'river', 'bspwm', 'dwm', 'qtile',
        'awesome', 'xmonad', 'herbstluftwm', 'leftwm', 'wayfire', 'labwc', 'dwl',
      ];
      final d = _desktop;
      return tiling.any(d.contains);
    } catch (_) {
      return false;
    }
  }

  /// Окружения, где свой заголовок с вкладками выглядит уместно.
  /// На macOS вкладки рисуем в своей полосе, а нативный светофор остаётся
  /// слева поверх неё (окно без заголовка, transparent titlebar).
  static bool get supportsCustomTitleBar {
    if (kIsWeb) return false;
    try {
      if (Platform.isWindows || Platform.isMacOS) return true;
      if (!Platform.isLinux || isTiling) return false;
      final d = _desktop;
      return d.contains('gnome') || d.contains('kde') || d.contains('plasma');
    } catch (_) {
      return false;
    }
  }

  /// Wayland: позицию окна задавать нельзя - это решает композитор.
  static bool get isWayland {
    if (kIsWeb) return false;
    try {
      return Platform.isLinux && (Platform.environment['WAYLAND_DISPLAY']?.isNotEmpty ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Является ли текущая платформа настольной (ПК/ноутбук).
  static bool get isDesktop {
    if (kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS;
    }
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Текущая платформа - macOS (нативный светофор, ⌘-шорткаты, свои пути).
  static bool get isMac {
    if (kIsWeb) return defaultTargetPlatform == TargetPlatform.macOS;
    try {
      return Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Является ли устройство мобильным (Android/iOS).
  static bool get isMobile {
    if (kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
    }
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }
}
