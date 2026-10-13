#!/usr/bin/env sh
# Проверяет, что third_party/xterm2/lib - это xterm2 с pub.dev плюс
# third_party/xterm2/vysh.patch, и ничего больше.
#
#   tools/xterm2/verify.sh            проверить
#   tools/xterm2/verify.sh --update   перезаписать lib из оригинала + патча
#                                     (после смены VERSION и SHA256 ниже)
set -eu

VERSION=5.2.0
SHA256=0b62e7510b414329dfb6ce7dbcffcfe97cc5109033573cf0f4abca568dac8149

root=$(cd "$(dirname "$0")/../.." && pwd)
dir="$root/third_party/xterm2"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "https://pub.dev/api/archives/xterm2-$VERSION.tar.gz" -o "$tmp/xterm2.tar.gz"
echo "$SHA256  $tmp/xterm2.tar.gz" | sha256sum -c - >/dev/null
mkdir "$tmp/src"
tar -xzf "$tmp/xterm2.tar.gz" -C "$tmp/src"
(cd "$tmp/src" && patch -p1 --quiet --forward < "$dir/vysh.patch")

if [ "${1:-}" = "--update" ]; then
  rm -rf "$dir/lib"
  cp -r "$tmp/src/lib" "$dir/lib"
  cp "$tmp/src/LICENSE" "$dir/LICENSE"
  echo "third_party/xterm2/lib обновлён: xterm2 $VERSION + vysh.patch"
  exit 0
fi

if diff -r --strip-trailing-cr "$tmp/src/lib" "$dir/lib"; then
  echo "third_party/xterm2 = xterm2 $VERSION + vysh.patch"
else
  echo "third_party/xterm2/lib отличается от xterm2 $VERSION + vysh.patch" >&2
  exit 1
fi
