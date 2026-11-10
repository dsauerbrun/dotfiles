#!/bin/bash
# Install Rex and serve it on the tailnet so the Mac client can reach this
# workspace at https://<hostname>.alpaca-tet.ts.net.
set -euo pipefail

hostname="${REX_TAILSCALE_HOSTNAME:-dsauerbrun-rex}"

if ! command -v rex >/dev/null; then
  # Other setup can still hold the dpkg lock, which fails the installer outright.
  for attempt in 1 2 3; do
    curl -fsSL https://pkgs.superlogical.com/rex/install.sh | sh && break
    if [ "$attempt" -eq 3 ]; then
      echo "ERROR: rex install failed" >&2
      exit 1
    fi
    sleep 20
  done
fi

# Ona containers have no systemd, so run a detached user server instead of the
# packaged rex.service. Start is a no-op when a server is already running.
rex server start --tailscale --tailscale-hostname "$hostname"

# A new workspace prints a Tailscale sign-in link here; later starts reuse the
# node state in ~/.local/state/rex.
rex server status | sed -n '/^tailscale/,/^log/p'
