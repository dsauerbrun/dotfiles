#! /bin/bash
set -x

# COPIED FROM THIS FILE: https://github.com/VantaInc/obsidian/blob/main/.devcontainer/bin/default-post-install-efs-hook#L21
##################################
# MAKE SURE YOU KEEP THIS SCRIPT UP TO DATE
##################################


# All of these segments will be symlinked from the home directory to your EFS drive.
# You can safely customize this list.
for segment in AGENTS.md .claude .claude.json .config/gh .codex .cursor .cursor-server; do
  # If you don't want to delete what's currently in the home directory, remove this.
  if [ -e "$HOME/$segment" ]; then
    rm -rf "$HOME/$segment"
  fi
  # Ensure the EFS-side target exists so directory symlinks don't dangle.
  case "$segment" in
    *.json) : ;;
    *) mkdir -p "$EFS_MOUNT_POINT/$segment" ;;
  esac
  mkdir -p "$(dirname "$HOME/$segment")"
  # Don't fail if the symlink already exists.
  ln -s "$EFS_MOUNT_POINT/$segment" "$HOME/$segment" || true
done

# OpenCode reads global instructions from ~/.config/opencode/AGENTS.md, so point it
# at the AGENTS.md above and keep a single real file. Deliberately outside the loop:
# syncing .config/opencode wholesale would export per-machine state, including the
# 0600 service credential in service.json, to every host on the NFS share.
mkdir -p "$HOME/.config/opencode"
ln -sfn ../../AGENTS.md "$HOME/.config/opencode/AGENTS.md"

# Keep .mcp.json as the source of truth for project-local OpenCode MCP servers.
workspace="${VANTA_WORKSPACE_DIR:-/workspaces/obsidian}"
python3 "$(dirname "$(readlink -f "$0")")/generate-opencode-mcp.py" "$workspace"

"$(dirname "$(readlink -f "$0")")/rexurrect/setup.sh" || echo "WARNING: rexurrect setup failed" >&2
"$(dirname "$(readlink -f "$0")")/rex-setup.sh"
