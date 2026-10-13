# xterm2 для vysh

Копия [xterm2](https://github.com/SoFluffyOS/xterm2) 5.2.0 (MIT, см. LICENSE) с одной правкой. Правка целиком лежит в [`vysh.patch`](vysh.patch); кроме неё, `lib/` совпадает с архивом pub.dev (sha256 `0b62e751…8149`).

## Правка

В оригинале `CustomTextEdit` жёстко задаёт `enableSuggestions: false` и `enableIMEPersonalizedLearning: false`. На Android из-за второго флага Gboard и другие клавиатуры открываются в анонимном режиме: клавиатуре запрещено обучение.

Оба флага стали параметрами `TerminalView`, по умолчанию `false`, как в оригинале. vysh передаёт `enableIMEPersonalizedLearning: true` (`lib/ui/terminal/session_view.dart`); `enableSuggestions` остаётся `false`: подсказки над строкой терминала не нужны, и для анонимного режима этот флаг значения не имеет. Проверено на устройстве в 0.4.2.

Тест: `test/xterm2_patch_test.dart` проверяет, что флаг доходит до системного ввода.

## Проверка и обновление

```sh
tools/xterm2/verify.sh            # lib/ = архив с pub.dev + vysh.patch (это же проверяет CI)
```

Чтобы перейти на новую версию xterm2: поменять `VERSION` и `SHA256` в `tools/xterm2/verify.sh` (sha256 есть в `https://pub.dev/api/packages/xterm2/versions/<версия>`, поле `archive_sha256`), выполнить `tools/xterm2/verify.sh --update`, поправить `version` в `pubspec.yaml` этой папки. Если патч не накладывается, правку нужно повторить руками и пересобрать `vysh.patch`.

Подключается в корневом pubspec.yaml через `dependency_overrides`. Когда в xterm2 появятся такие параметры, папку можно удалить.

Основной `flutter analyze` исключает `third_party/**`: это чужой код, его стиль не правим.
