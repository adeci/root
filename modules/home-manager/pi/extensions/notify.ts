/**
 * Notify Extension
 *
 * Sends a native terminal notification when the agent finishes and is
 * waiting for input. Supports multiple terminal protocols:
 * - OSC 777: Ghostty, iTerm2, WezTerm, rxvt-unicode
 * - OSC 99: Kitty
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

function notifyOSC777(title: string, body: string): void {
  process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
}

function notifyOSC99(title: string, body: string): void {
  process.stdout.write(`\x1b]99;i=1:d=0;${title}\x1b\\`);
  process.stdout.write(`\x1b]99;i=1:p=body;${body}\x1b\\`);
}

function notify(title: string, body: string): void {
  if (process.env.KITTY_WINDOW_ID) {
    notifyOSC99(title, body);
  } else {
    notifyOSC777(title, body);
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async () => {
    notify("pi", "Ready for input");
  });
}
