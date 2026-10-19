# irondash_engine_context для vysh

Копия пакета с pub.dev (лицензия в LICENSE) с одной правкой в `cargokit/gradle/plugin.gradle`:
`project.exec {}` убран в Gradle 9, сборка APK падала с «Could not find method exec()».
Команда теперь запускается через `ExecOperations`.

Rust-исходники не тронуты, поэтому хеш крейта прежний и cargokit по-прежнему
скачивает готовые бинарники, Rust ставить не нужно.

Подключается через `dependency_overrides` в pubspec.yaml. Когда выйдет версия
с поддержкой Gradle 9 и без обязательного Rust, папку можно удалить.
