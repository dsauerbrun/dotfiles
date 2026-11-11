#!/bin/bash
# Install Rex and serve it on the tailnet so the Mac client can reach this
# workspace at https://<hostname>.alpaca-tet.ts.net.
#
# This is the one place that decides how the server starts. It runs from
# post-start-install.sh on every workspace start, from .zshrc on the first SSH
# login that finds no server, and in place of a bare "rex server start" typed
# by hand (see the rex function in .zshrc). Every path gets the same flags.
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
# packaged rex.service. Start is a no-op when a server is already running, and
# its flags only apply to a server it launches itself.
rex server start --tailscale --tailscale-hostname "$hostname"

# A server that something else launched first (a bare "rex server start", or a
# rex command's autostart) came up with Tailscale's default node name, "rex",
# which the tailnet then suffixes to rex-2 and so on. Fix that in place rather
# than restarting, which would end every session. Tailscale may itself add a
# numeric suffix to our name when it collides, so accept hostname-N as well.
read -r ts_state ts_node < <(rex server status --autostart=false --json | python3 -I -c '
import json, sys
ts = json.load(sys.stdin).get("tailscale") or {}
print(ts.get("state") or "disabled", (ts.get("dns_name") or "").split(".")[0])')

if [ "$ts_state" = "disabled" ]; then
  echo "rex: Tailscale is off on the running server, turning it on as $hostname"
  rex server tailscale on --hostname "$hostname"
elif [ -n "${ts_node:-}" ] && [ "$ts_node" != "$hostname" ]; then
  case "$ts_node" in
    "$hostname"-[0-9]*) ;;
    *)
      echo "rex: Tailscale node is $ts_node, renaming to $hostname"
      rex server tailscale rename "$hostname"
      ;;
  esac
fi

# A new workspace prints a Tailscale sign-in link here; later starts reuse the
# node state in ~/.local/state/rex.
rex server status | sed -n '/^tailscale/,/^log/p'

# End with the tailnet URL alone on a line, so it is easy to copy. The HTTPS
# certificate can take up to a minute after a fresh start, so wait for it
# briefly and say so if it is still pending.
for _ in $(seq 1 12); do
  read -r ts_dns ts_https < <(rex server status --autostart=false --json | python3 -I -c '
import json, sys
ts = json.load(sys.stdin).get("tailscale") or {}
print(ts.get("dns_name") or "-", (ts.get("https") or {}).get("state") or "pending")')
  [ "$ts_https" = "available" ] && break
  sleep 5
done
if [ "$ts_dns" != "-" ]; then
  echo
  if [ "$ts_https" = "available" ]; then
    echo "rex tailnet url:"
  else
    echo "rex tailnet url (https still $ts_https, retry rex-status in a minute):"
  fi
  echo "https://$ts_dns"
fi
