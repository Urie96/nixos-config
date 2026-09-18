/**
 * Pi Notify Extension
 *
 * Sends a native terminal notification when Pi agent is done and waiting for input.
 * Supports multiple terminal protocols:
 * - OSC 777: Ghostty, iTerm2, WezTerm, rxvt-unicode
 * - OSC 99: Kitty
 * - Windows toast: Windows Terminal (WSL)
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

function notifyOSC99(title: string, body: string): void {
  // Kitty OSC 99: i=notification id, d=0 means not done yet, p=body for second part
  const titleSequence = `\x1b]99;i=1:d=0;${title}\x1b\\`;
  const bodySequence = `\x1b]99;i=1:p=body;${body}\x1b\\`;
  process.stdout.write(wrapForTmux(titleSequence));
  process.stdout.write(wrapForTmux(bodySequence));
}

function wrapForTmux(sequence: string): string {
  if (!process.env.TMUX) return sequence;

  // tmux passthrough: wrap in DCS and escape inner ESC bytes.
  const escaped = sequence.split("\x1b").join("\x1b\x1b");
  return `\x1bPtmux;${escaped}\x1b\\`;
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async () => {
    process.stdout.write("\x07");
    notifyOSC99("Pi", "Ready for input");
  });
}
