// Reports the root OpenCode session in this Rex block to rexurrect, so a
// restore can resume it with `opencode --session <id>`.
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const REXURRECT = join(homedir(), ".cargo/bin/rexurrect");

export const RexurrectPlugin = async () => {
  if (!process.env.REX_BLOCK || !existsSync(REXURRECT)) {
    return {};
  }

  const childSessions = new Set();
  let reported;

  const report = (sessionID) => {
    if (!sessionID || sessionID === reported || childSessions.has(sessionID)) {
      return;
    }
    reported = sessionID;
    // `report` never prints and always exits 0; don't let it hold OpenCode up.
    spawn(REXURRECT, ["report", "opencode", sessionID], {
      stdio: "ignore",
      detached: true,
    }).unref();
  };

  return {
    "chat.message": async ({ sessionID }) => report(sessionID),
    event: async ({ event }) => {
      const info = event?.properties?.info;
      if (info?.id && info.parentID) {
        childSessions.add(info.id);
      }
    },
  };
};
