import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controllers/settings_controller.dart';
import '../../l10n/app_strings.dart';

extension StringsContext on BuildContext {
  /// Строки на языке из настроек - для диалогов и функций без `ref`.
  /// Не подписывает виджет на смену языка: экраны, которые должны
  /// перестраиваться, берут язык через `ref.watch`.
  AppStrings get strings => AppStrings.of(
        this,
        ProviderScope.containerOf(this, listen: false).read(settingsProvider).language,
      );
}
