#!/bin/bash
# Install rexurrect and wire it in: auto-restore when the Rex server starts,
# autosave every 15 minutes, and resume for Claude Code, Codex and OpenCode.
# Idempotent; run before the Rex server starts so init.lua is in place.
# Undo with uninstall.sh.
set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"

VERSION=0.4.0
declare -A SHA256=(
  [x86_64]=d4023856dc6c67e5cc64f7a2564bf0a8c6fe32ac8b372d53cbf3b34e89528a4e
  [aarch64]=cb4c9ab1ebf6fa4d8b759ffd8bf046eb158f141181c8be71684a049132ad93c5
)

BIN="$HOME/.cargo/bin/rexurrect"
RECORDER="$HOME/.zsh/rexurrect.plugin.zsh"
STATE_DIR="$HOME/.local/state/rexurrect"
CONFIG="$HOME/.config/rexurrect/config.toml"
INIT_LUA="$HOME/.config/rex/init.lua"
# rex-setup.sh starts the server on rex's default endpoint; cron needs it named.
REX_SERVER_URL="unix://$HOME/.local/state/rex/run/server.sock"

install_binary() {
  if [ -x "$BIN" ] && [ "$("$BIN" --version)" = "rexurrect $VERSION" ] && [ -r "$RECORDER" ]; then
    return
  fi
  local arch target tmp
  arch="$(uname -m)"
  target="rexurrect-$arch-unknown-linux-musl"
  [ -n "${SHA256[$arch]:-}" ] || { echo "rexurrect: no build for $arch" >&2; return 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL -o "$tmp/$target.tar.xz" \
    "https://github.com/cemcatik/rexurrect/releases/download/v$VERSION/$target.tar.xz"
  echo "${SHA256[$arch]}  $tmp/$target.tar.xz" | sha256sum -c --quiet
  tar -xJf "$tmp/$target.tar.xz" -C "$tmp"
  mkdir -p "$(dirname "$BIN")" "$(dirname "$RECORDER")"
  install -m 0755 "$tmp/$target/rexurrect" "$BIN"
  install -m 0644 "$tmp/$target/rexurrect.plugin.zsh" "$RECORDER"
  echo "rexurrect: installed $VERSION"
}

install_auto_restore() {
  local hook rest
  hook="$("$BIN" auto-restore --print-hook)"
  mkdir -p "$(dirname "$INIT_LUA")"
  rest="$(grep -v rexurrect "$INIT_LUA" 2>/dev/null || true)"
  printf '%s\n' ${rest:+"$rest"} "$hook" > "$INIT_LUA"
}

install_autosave() {
  local line="*/15 * * * * REX_SERVER=$REX_SERVER_URL REXURRECT_STATE_DIR=$STATE_DIR REXURRECT_CONFIG=$CONFIG $BIN save >/dev/null 2>&1 # rexurrect-autosave"
  { crontab -l 2>/dev/null | grep -v '# rexurrect-autosave' || true; echo "$line"; } | crontab -
  pgrep -x cron >/dev/null || echo "rexurrect: cron isn't running, so autosave won't run" >&2
}

install_binary
install -D -m 0644 "$here/config.toml" "$CONFIG"
install -D -m 0644 "$here/opencode-plugin.js" "$HOME/.config/opencode/plugins/rexurrect.js"
install_auto_restore
install_autosave
python3 -I "$here/agent-hooks.py" add "$BIN" "$STATE_DIR" "$CONFIG"
grep -q '^hooks *= *true' "$HOME/.codex/config.toml" 2>/dev/null ||
  echo "rexurrect: set hooks = true under [features] in ~/.codex/config.toml for Codex resume" >&2
