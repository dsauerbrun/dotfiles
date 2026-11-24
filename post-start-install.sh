#! /bin/bash
set -x

# Based on https://github.com/VantaInc/obsidian/blob/main/.devcontainer/bin/default-post-install-efs-hook#L21
# The linking below has diverged from it on purpose: it leaves existing links
# alone and merges instead of deleting (see link_to_efs).


# Symlinks $HOME/<segment> to the same path on the EFS drive.
#
# The home directory survives a restart, so the link is usually already in
# place: leave it alone. The Rex server can start before this hook and
# rexurrect then resumes agents straight away; removing and relinking under
# them makes them recreate ~/.claude as a plain directory between the rm and
# the ln, which hides every session on EFS.
#
# When the home path is a plain directory, its contents are merged into EFS
# (never overwriting EFS files) before it is replaced, so nothing an agent
# wrote there is lost.
link_to_efs() {
  local segment=$1
  local home_path="$HOME/$segment" efs_path="$EFS_MOUNT_POINT/$segment"

  # Ensure the EFS-side target exists so directory symlinks don't dangle.
  case "$segment" in
    *.json) : ;;
    *) mkdir -p "$efs_path" ;;
  esac

  [ "$(readlink "$home_path")" = "$efs_path" ] && return 0

  mkdir -p "$(dirname "$home_path")"
  local attempt
  for attempt in 1 2 3; do
    if [ -d "$home_path" ] && [ ! -L "$home_path" ]; then
      # A previous lost race leaves the link nested inside the directory.
      local nested="$home_path/$(basename "$segment")"
      [ "$(readlink "$nested")" = "$efs_path" ] && rm -f "$nested"
      cp -a --update=none "$home_path/." "$efs_path/"
    elif [ -f "$home_path" ] && [ ! -L "$home_path" ] && [ ! -e "$efs_path" ]; then
      mv "$home_path" "$efs_path"
    fi
    rm -rf "$home_path"
    # -T: fail rather than create the link inside a directory recreated since the rm.
    ln -sT "$efs_path" "$home_path" 2>/dev/null
    [ "$(readlink "$home_path")" = "$efs_path" ] && return 0
  done
  echo "ERROR: could not link $home_path to $efs_path" >&2
  return 1
}

# You can safely customize this list.
for segment in AGENTS.md .claude .claude.json .config/gh .codex .cursor .cursor-server; do
  link_to_efs "$segment"
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
