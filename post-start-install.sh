#! /bin/bash
set -x

# All of these segments will be symlinked from the home directory to your EFS drive.
# You can safely customize this list.
for segment in AGENTS.md .claude .claude.json .codex .cursor .cursor-server; do
  # If you don't want to delete what's currently in the home directory, remove this.
  if [ -e "$HOME/$segment" ]; then
    rm -rf "$HOME/$segment"
  fi
  # Don't fail if the symlink already exists.
  ln -s "$EFS_MOUNT_POINT/$segment" "$HOME" || true
done

# OpenCode reads global instructions from ~/.config/opencode/AGENTS.md, so point it
# at the AGENTS.md above and keep a single real file. Deliberately outside the loop:
# syncing .config/opencode wholesale would export per-machine state, including the
# 0600 service credential in service.json, to every host on the NFS share.
mkdir -p "$HOME/.config/opencode"
ln -sfn ../../AGENTS.md "$HOME/.config/opencode/AGENTS.md"
