# rexurrect

Saves Rex sessions and brings them back after the workspace restarts, with
Claude Code, Codex and OpenCode resumed in their conversations. Uses
https://github.com/cemcatik/rexurrect, wired for Ona: cron instead of the
systemd timer rexurrect expects on Linux.

`setup.sh` runs from `post-start-install.sh`, before `rex-setup.sh` starts the
server, and installs:

- the binary (pinned version and checksum) in `~/.cargo/bin`, and its zsh
  recorder in `~/.zsh`;
- `config.toml` in `~/.config/rexurrect/`, and `opencode-plugin.js` as
  `~/.config/opencode/plugins/rexurrect.js`;
- the auto-restore line in `~/.config/rex/init.lua`;
- a `rexurrect save` crontab entry, every `AUTOSAVE_MINUTES` (1) minutes;
- a `SessionStart` hook in `~/.claude/settings.json` and `~/.codex/hooks.json`
  (`agent-hooks.py`).

To upgrade, bump `VERSION` and both `SHA256` values in `setup.sh`.

## Removing it

1. Run `rexurrect/uninstall.sh` on each workspace that has it.
2. Delete this directory.
3. Delete the `rexurrect` line in `post-start-install.sh` and in `.zshrc`.
