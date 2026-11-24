#! /bin/bash
set -x

# Based on https://github.com/VantaInc/obsidian/blob/main/.devcontainer/bin/default-post-install-efs-hook#L21
# The linking below has diverged from it on purpose: it leaves existing links
# alone and merges instead of deleting (see link_to_efs).


# Copies files from a stray home directory into EFS. Files missing from EFS are
# copied. A file on both sides keeps the EFS copy, except a .jsonl transcript:
# an agent resumed while the link was missing appended to its own copy, so the
# larger (longer) transcript wins.
merge_into_efs() {
  local src=$1 dst=$2 rel
  (cd "$src" && find . -type f -print0) | while IFS= read -r -d '' rel; do
    rel=${rel#./}
    if [ ! -e "$dst/$rel" ]; then
      mkdir -p "$(dirname "$dst/$rel")"
      cp -a "$src/$rel" "$dst/$rel"
    elif [[ $rel == *.jsonl ]] && [ -f "$dst/$rel" ] &&
      [ "$(stat -c %s "$src/$rel")" -gt "$(stat -c %s "$dst/$rel")" ]; then
      cp -a "$src/$rel" "$dst/$rel"
    fi
  done
}

# Symlinks $HOME/<segment> to the same path on the EFS drive.
#
# The home directory survives a restart, so the link is usually already in
# place: leave it alone. The Rex server can start before this hook and
# rexurrect then resumes agents straight away; removing and relinking under
# them makes them recreate ~/.claude as a plain directory between the rm and
# the ln, which hides every session on EFS.
#
# When the home path is a plain directory, its contents are merged into EFS
# before it is replaced (see merge_into_efs), and the directory itself is moved
# to $EFS_MOUNT_POINT/.link-repair-backups rather than deleted, so nothing an
# agent wrote there is lost.
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
      merge_into_efs "$home_path" "$efs_path"
      local backups="$EFS_MOUNT_POINT/.link-repair-backups"
      mkdir -p "$backups"
      local name=${segment#.}
      mv "$home_path" "$backups/${name//\//_}.$(date -u +%Y%m%dT%H%M%SZ).$attempt"
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

# Personal agent-neutral skills live once in dotfiles/skills and are linked into each
# agent's user skills directory. OpenCode needs no link: it already reads ~/.claude/skills.
mkdir -p "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.pi/agent/skills"
for skill in "$(dirname "$(readlink -f "$0")")"/skills/*/; do
  [ -d "$skill" ] || continue
  name="$(basename "$skill")"
  for dir in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.pi/agent/skills"; do
    ln -sfnT "${skill%/}" "$dir/$name"
  done
done

# Keep .mcp.json as the source of truth for project-local OpenCode MCP servers.
workspace="${VANTA_WORKSPACE_DIR:-/workspaces/obsidian}"
python3 "$(dirname "$(readlink -f "$0")")/generate-opencode-mcp.py" "$workspace"

"$(dirname "$(readlink -f "$0")")/rexurrect/setup.sh" || echo "WARNING: rexurrect setup failed" >&2
"$(dirname "$(readlink -f "$0")")/rex-setup.sh"
