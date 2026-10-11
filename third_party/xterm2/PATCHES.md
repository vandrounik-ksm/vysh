# xterm2 для vysh

Копия [xterm2](https://github.com/SoFluffyOS/xterm2) 5.2.0 (MIT, см. LICENSE) с одной правкой.

В оригинале `CustomTextEdit` жёстко задаёт `enableSuggestions: false` и `enableIMEPersonalizedLearning: false`. На Android из-за этого Gboard и другие клавиатуры открываются в анонимном режиме: Flutter помечает поле как пароль и запрещает обучение.

Правка: оба флага стали параметрами `TerminalView` (по умолчанию как в оригинале, `false`), vysh включает их на Android.

Подключается в pubspec.yaml через `dependency_overrides`. Когда в xterm2 появятся такие параметры, папку можно удалить.
