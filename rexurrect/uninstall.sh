#!/bin/bash
# Undo setup.sh on this machine. Snapshots in ~/.local/state/rexurrect are
# kept; delete that directory too to remove every trace.
set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
INIT_LUA="$HOME/.config/rex/init.lua"

{ crontab -l 2>/dev/null | grep -v '# rexurrect-autosave' || true; } | crontab -
if [ -f "$INIT_LUA" ]; then
  rest="$(grep -v rexurrect "$INIT_LUA" || true)"
  if [ -n "$rest" ]; then
    printf '%s\n' "$rest" > "$INIT_LUA"
  else
    rm "$INIT_LUA"
  fi
fi
python3 -I "$here/agent-hooks.py" remove - - -
rm -f "$HOME/.cargo/bin/rexurrect" "$HOME/.zsh/rexurrect.plugin.zsh" \
  "$HOME/.config/opencode/plugins/rexurrect.js"
rm -rf "$HOME/.config/rexurrect"
echo "rexurrect: removed; snapshots remain in ~/.local/state/rexurrect"
