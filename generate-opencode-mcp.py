#!/usr/bin/env python3
"""Generate project-local OpenCode MCP configuration from Claude's .mcp.json."""

import json
import os
import subprocess
import sys
from pathlib import Path


MARKER = "// Generated from .mcp.json by dotfiles/generate-opencode-mcp.py. Do not edit."


def main() -> None:
    workspace = Path(sys.argv[1])
    source = workspace / ".mcp.json"
    target = workspace / ".opencode" / "opencode.jsonc"

    if not source.is_file():
        print(f"Skipping OpenCode MCP setup: {source} does not exist")
        return

    if target.exists() and not target.read_text().startswith(MARKER + "\n"):
        raise SystemExit(f"Refusing to overwrite a non-generated config: {target}")

    servers = json.loads(source.read_text())["mcpServers"]
    converted = {}
    for name, server in servers.items():
        if server.get("type", "stdio") != "stdio":
            raise SystemExit(f"Unsupported MCP transport for {name}; no config written")
        converted[name] = {
            "type": "local",
            "command": [server["command"], *server.get("args", [])],
        }
        if server.get("env"):
            converted[name]["environment"] = {
                key: "{env:" + key + "}" for key in server["env"]
            }

    config = {"$schema": "https://opencode.ai/config.json", "mcp": {"servers": converted}}
    content = MARKER + "\n" + json.dumps(config, indent=2) + "\n"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    os.chmod(target, 0o600)

    exclude_path = subprocess.run(
        [
            "git", "-C", str(workspace), "rev-parse", "--path-format=absolute",
            "--git-path", "info/exclude",
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    exclude = Path(exclude_path)
    ignored_path = "/.opencode/opencode.jsonc"
    if ignored_path not in exclude.read_text().splitlines():
        with exclude.open("a") as file:
            file.write("\n" + ignored_path + "\n")
    print(f"Generated OpenCode MCP config at {target}")


if __name__ == "__main__":
    main()
