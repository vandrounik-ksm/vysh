#!/bin/sh
# Демо-стенд на Linux: то же, что start.bat.
set -e
here=$(cd "$(dirname "$0")" && pwd)
export VYSH_DEMO_DIR="${TMPDIR:-/tmp}/vysh-demo"
mkdir -p "$VYSH_DEMO_DIR"
[ -f "$VYSH_DEMO_DIR/demo_key" ] || ssh-keygen -q -t ed25519 -N "" -C vysh-demo -f "$VYSH_DEMO_DIR/demo_key"
docker compose -f "$here/docker-compose.yml" up -d --build
sed "s|__KEY__|$VYSH_DEMO_DIR/demo_key|" "$here/hosts.json" > "$VYSH_DEMO_DIR/hosts.json"
[ -f "$VYSH_DEMO_DIR/settings.json" ] || cp "$here/settings.json" "$VYSH_DEMO_DIR/settings.json"
cd "$here/../.."
VYSH_CONFIG_DIR="$VYSH_DEMO_DIR" flutter run -d linux --release
