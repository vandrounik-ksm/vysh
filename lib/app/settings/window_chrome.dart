import '../../infra/platform/capabilities.dart';
import '../../infra/platform/desktop_env.dart';
import 'app_settings.dart';

/// Итог настройки «Заголовок окна»: рисуем ли свой заголовок с вкладками.
bool useCustomTitleBar(TitleBarMode mode) => switch (mode) {
      TitleBarMode.custom => PlatformCapabilities.desktopWindow,
      TitleBarMode.system => false,
      TitleBarMode.auto => DesktopEnv.supportsCustomTitleBar,
    };
