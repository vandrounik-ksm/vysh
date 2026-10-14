#!/usr/bin/env bash
# Сборка vysh.app для macOS и упаковка в DMG.
# Локальный аналог tools/build-windows.ps1: версия и номер сборки - из
# pubspec.yaml, дата сборки передаётся через --dart-define BUILD_DATE.
#
# Требует: flutter в PATH и Xcode (Command Line Tools достаточно).
# Сторонние утилиты не нужны: DMG собирается штатным hdiutil.
set -e
cd "$(dirname "$0")/.."

# flutter может не быть в PATH интерактивной оболочки - ищем в типичных местах.
if ! command -v flutter >/dev/null 2>&1; then
  for d in "$HOME/development/flutter/bin" "$HOME/flutter/bin" "/opt/flutter/bin" "/usr/local/flutter/bin"; do
    if [ -x "$d/flutter" ]; then export PATH="$d:$PATH"; break; fi
  done
fi
command -v flutter >/dev/null 2>&1 || { echo "Ошибка: flutter не найден в PATH" >&2; exit 1; }

BUILD_TIME=$(date '+%d.%m.%y %H:%M:%S')
VERSION=$(sed -nE 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1 | cut -d'+' -f1)
BUILD_NUM=$(sed -nE 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1 | cut -d'+' -f2)
[ -n "$VERSION" ] || VERSION="0.0.0"
[ -n "$BUILD_NUM" ] || BUILD_NUM="0"

echo "==> Сборка macOS (Release, $VERSION+$BUILD_NUM)"
flutter build macos --release --dart-define="BUILD_DATE=$BUILD_TIME" >/dev/null

APP_PATH="build/macos/Build/Products/Release/vysh.app"
[ -d "$APP_PATH" ] || { echo "Ошибка: $APP_PATH не найден" >&2; exit 1; }

DMG_OUT="build/vysh-$VERSION-macos.dmg"
STAGING="build/dmg_staging"

echo "==> Упаковка DMG"
rm -rf "$STAGING"
[ -f "$DMG_OUT" ] && mv "$DMG_OUT" "$DMG_OUT.old"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/vysh.app"
cp LICENSE "$STAGING/LICENSE"
ln -s /Applications "$STAGING/Applications"

# Иконка тома: если .icns есть - кладём как значок тома.
if [ -f assets/icon/vysh-macos.icns ]; then
  cp assets/icon/vysh-macos.icns "$STAGING/.VolumeIcon.icns"
fi

# UDZO: сжатый образ без шифрования. Тихий режим: прогресс hdiutil
# не нужен. Уже открытый пользователем том «vysh» НЕ трогаем:
# hdiutil create только пишет новый файл, чужой том не отмонтируется.
hdiutil create -volname "vysh" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG_OUT"

rm -rf "$STAGING"
rm -f "$DMG_OUT.old" 2>/dev/null || true

echo "Готово: $DMG_OUT"
