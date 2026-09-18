import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  let working = false;

  function fire(event: "start" | "end" | "exit"): void {
    const args: string[] = [event];
    const session = pi.getSessionName();
    if (session) {
      args.push("--session", session);
    }
    pi.exec("coding-agent-status", args, { stdio: "inherit" });
  }

  pi.on("agent_start", () => {
    working = true;
    fire("start");
  });

  pi.on("agent_end", () => {
    working = false;
    fire("end");
  });

  pi.on("session_shutdown", () => {
    if (working) {
      working = false;
      fire("end");
    }
    fire("exit");
  });
}
