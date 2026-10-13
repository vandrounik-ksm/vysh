#!/usr/bin/env bash
# Сборка vysh.app для macOS и упаковка в DMG.
# Локальный аналог tools/build-windows.ps1: версия и номер сборки - из
# pubspec.yaml, дата сборки передаётся через --dart-define BUILD_DATE.
#
# Требует: flutter, create-dmg (brew install create-dmg); без него DMG
# собирается штатным hdiutil.
set -e
cd "$(dirname "$0")/.."

BUILD_TIME=$(date '+%d.%m.%y %H:%M:%S')
VERSION=$(sed -nE 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1 | cut -d'+' -f1)
BUILD_NUM=$(sed -nE 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1 | cut -d'+' -f2)
[ -n "$VERSION" ] || VERSION="0.0.0"
[ -n "$BUILD_NUM" ] || BUILD_NUM="0"

echo "==> Сборка macOS (Release, $VERSION+$BUILD_NUM, BUILD_DATE=$BUILD_TIME)"
flutter build macos --release --dart-define="BUILD_DATE=$BUILD_TIME"

APP_PATH="build/macos/Build/Products/Release/vysh.app"
[ -d "$APP_PATH" ] || { echo "Ошибка: $APP_PATH не найден" >&2; exit 1; }

# Иконка тома для DMG (если есть icns).
VOLICON_FLAG=""
if [ -f assets/icon/vysh-macos.icns ]; then
  VOLICON_FLAG="--volicon assets/icon/vysh-macos.icns"
fi

DMG_OUT="build/vysh-${VERSION}-macos.dmg"
mkdir -p build

if command -v create-dmg >/dev/null 2>&1; then
  echo "==> DMG через create-dmg"
  rm -f "$DMG_OUT"
  create-dmg \
    --volname "vysh" \
    $VOLICON_FLAG \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "vysh.app" 160 205 \
    --app-drop-link 500 205 \
    --hide-extension "vysh.app" \
    --applescript-sleep-duration 1 \
    --overwrite \
    "$DMG_OUT" \
    "$APP_PATH" || {
      # create-dmg иногда падает из-за AppleScript в CI - fallback ниже.
      echo "create-dmg не справился, пробуем hdiutil"
    }
fi

if [ ! -f "$DMG_OUT" ]; then
  echo "==> DMG через hdiutil (без сторонних утилит)"
  STAGING="build/dmg_staging"
  rm -rf "$STAGING" "$DMG_OUT"
  mkdir -p "$STAGING"
  cp -R "$APP_PATH" "$STAGING/vysh.app"
  ln -s /Applications "$STAGING/Applications"
  if [ -f assets/icon/vysh-macos.icns ]; then
    cp assets/icon/vysh-macos.icns "$STAGING/.VolumeIcon.icns"
    command -v SetFile >/dev/null 2>&1 && SetFile -a C "$STAGING" 2>/dev/null || true
  fi
  hdiutil create -volname "vysh" -srcfolder "$STAGING" -ov -format UDZO "$DMG_OUT"
  rm -rf "$STAGING"
fi

echo ""
echo "Готово: $DMG_OUT"
