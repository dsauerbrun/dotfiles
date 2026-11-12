"""Add or remove rexurrect's SessionStart hook in Claude Code's and Codex's config.

Usage: agent-hooks.py add|remove BIN STATE_DIR CONFIG

Both files live on EFS and are shared by every workspace, so the hook is a
no-op on one without rexurrect installed. Files are rewritten in place so a
symlink pointing at them stays attached.
"""

import json
import os
import sys

TARGETS = [("~/.claude/settings.json", "claude"), ("~/.codex/hooks.json", "codex")]


def is_rexurrect_entry(entry):
    return any("rexurrect" in h.get("command", "") for h in entry.get("hooks", []))


def main():
    mode, bin_path, state_dir, config = sys.argv[1:5]
    for raw_path, program in TARGETS:
        path = os.path.expanduser(raw_path)
        if not os.path.exists(path):
            if mode == "remove":
                continue
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write("{}\n")
        with open(path) as f:
            data = json.load(f)
        session_start = data.setdefault("hooks", {}).setdefault("SessionStart", [])
        session_start[:] = [e for e in session_start if not is_rexurrect_entry(e)]
        if mode == "add":
            command = (
                f"/bin/sh -c '[ -x {bin_path} ] && REXURRECT_STATE_DIR={state_dir} "
                f"REXURRECT_CONFIG={config} {bin_path} report {program}; true'"
            )
            session_start.append(
                {"hooks": [{"type": "command", "command": command, "timeout": 5}]}
            )
        elif not session_start:
            del data["hooks"]["SessionStart"]
        with open(path, "r+") as f:
            f.seek(0)
            f.write(json.dumps(data, indent=2) + "\n")
            f.truncate()


if __name__ == "__main__":
    main()
