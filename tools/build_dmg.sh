#!/usr/bin/env bash
# Сборка vysh.app для macOS и упаковка в DMG с оформлением.
# Локальный аналог tools/build-windows.ps1: версия и номер сборки - из
# pubspec.yaml, дата сборки передаётся через --dart-define BUILD_DATE.
#
# Требует: flutter в PATH и Xcode (Command Line Tools достаточно).
# Сторонние утилиты не нужны: разметку окна DMG делает Finder через
# AppleScript (как create-dmg, но управляемо): монтируем СВОЙ свежий
# образ в свою точку, настраиваем вид и отмонтируем только её -
# уже открытые пользователем томы «vysh» не трогаем.
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
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/vysh.app"
ln -s /Applications "$STAGING/Applications"

# Иконка тома.
if [ -f assets/icon/vysh-macos.icns ]; then
  cp assets/icon/vysh-macos.icns "$STAGING/.VolumeIcon.icns"
fi

# Сжатый образ без шифрования. Тихий режим: прогресс hdiutil не нужен.
# Уже открытый пользователем том «vysh» не затрагивается: create только
# пишет файл.
hdiutil create -volname "vysh" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG_OUT"
rm -rf "$STAGING"

# ─── Оформление окна DMG ──────────────────────────────────────────
# Монтируем СВОЮ rw-копию свежего образа в приватную точку, задаём вид
# окна Finder и пакуем обратно. Открытые пользователем томы «vysh»
# не трогаем: Finder видит наш диск по имени точки монтирования.
echo "==> Оформление окна DMG"
RW_DMG="build/vysh-rw-tmp.dmg"
MOUNT="/private/tmp/vysh-dmg-layout-$$"
DISK_NAME=$(basename "$MOUNT")

hdiutil convert "$DMG_OUT" -format UDRW -ov -o "$RW_DMG" -quiet
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT" -quiet -nobrowse

# Раскладка: окно 660x400, vysh.app слева, ссылка «Программы» справа,
# иконки 128, тёмный фон. Лицензия остаётся внутри .app и в README.
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$DISK_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 860, 520}
    set arrangement of the icon view options of container window to not arranged
    set icon size of the icon view options of container window to 128
    set position of item "vysh" of container window to {160, 205}
    set position of item "Applications" of container window to {500, 205}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
hdiutil convert "$RW_DMG" -format UDZO -ov -o "$DMG_OUT" -quiet
rm -f "$RW_DMG" 2>/dev/null || true

echo "Готово: $DMG_OUT"
