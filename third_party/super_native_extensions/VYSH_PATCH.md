# super_native_extensions для vysh

Копия пакета с pub.dev (лицензия в LICENSE) с правками в `cargokit/gradle/plugin.gradle`:
`project.exec {}` убран в Gradle 9, сборка APK падала с «Could not find method exec()».
Команда теперь запускается через `ExecOperations`.

Вторая правка - `android/build.gradle`: `compileSdkVersion` 36 вместо 31, иначе
сборка APK падает на проверке AAR (device_info_plus и androidx требуют 33-36).
minSdk и поведение на устройстве это не меняет.

Rust-исходники не тронуты, поэтому хеш крейта прежний и cargokit по-прежнему
скачивает готовые бинарники, Rust ставить не нужно.

Подключается через `dependency_overrides` в pubspec.yaml. Когда выйдет версия
с поддержкой Gradle 9 и без обязательного Rust, папку можно удалить.
