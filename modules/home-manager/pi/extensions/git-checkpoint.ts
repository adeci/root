import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

interface Checkpoint {
  stashRef: string;
  entryId: string;
  timestamp: number;
  description: string;
}

export default function (pi: ExtensionAPI) {
  const checkpoints: Checkpoint[] = [];
  let currentEntryId: string | undefined;

  pi.on("tool_result", (event) => {
    if ("entryId" in event && typeof event.entryId === "string") {
      currentEntryId = event.entryId;
    }
  });

  pi.on("turn_start", async (_event, ctx) => {
    const { stdout: status } = await pi.exec("git", ["status", "--porcelain"], {
      cwd: ctx.cwd,
    });
    if (!status.trim()) return;

    const { stdout: stashRef, code } = await pi.exec(
      "git",
      ["stash", "create"],
      { cwd: ctx.cwd },
    );
    if (code !== 0 || !stashRef.trim()) return;

    const { stdout: log } = await pi.exec("git", ["log", "--oneline", "-1"], {
      cwd: ctx.cwd,
    });

    checkpoints.push({
      stashRef: stashRef.trim(),
      entryId: currentEntryId || "unknown",
      timestamp: Date.now(),
      description: log.trim() || "checkpoint",
    });
  });

  pi.on("session_before_fork", async (_event, ctx) => {
    if (checkpoints.length === 0) return;

    if (!ctx.hasUI) return;

    const options = checkpoints.map((cp, i) => ({
      label: `[${i + 1}] ${new Date(cp.timestamp).toLocaleTimeString()} - ${cp.description}`,
      value: String(i),
    }));
    options.unshift({ label: "Keep current state", value: "skip" });

    const choice = await ctx.ui.select("Restore a checkpoint?", options);
    if (!choice || choice === "skip") return;

    const idx = parseInt(choice, 10);
    const cp = checkpoints[idx];
    if (!cp) return;

    const { code } = await pi.exec("git", ["stash", "apply", cp.stashRef], {
      cwd: ctx.cwd,
    });
    if (code === 0) {
      ctx.ui.notify(
        `Restored checkpoint from ${new Date(cp.timestamp).toLocaleTimeString()}`,
        "info",
      );
    } else {
      ctx.ui.notify("Failed to restore checkpoint (conflicts?)", "warning");
    }
  });

  pi.on("agent_end", () => {
    checkpoints.length = 0;
  });

  pi.registerCommand("checkpoint", {
    description: "Manage git checkpoints: list, create, restore",
    handler: async (args: string, ctx) => {
      const subcommand = args.trim().split(/\s+/)[0] || "list";

      if (subcommand === "list") {
        if (checkpoints.length === 0) {
          ctx.ui.notify("No checkpoints available", "info");
          return;
        }
        const lines = checkpoints.map(
          (cp, i) =>
            `[${i + 1}] ${new Date(cp.timestamp).toLocaleTimeString()} - ${cp.description} (${cp.stashRef.slice(0, 8)})`,
        );
        ctx.ui.notify(lines.join("\n"), "info");
      } else if (subcommand === "create") {
        const { stdout: stashRef, code } = await pi.exec(
          "git",
          ["stash", "create"],
          { cwd: ctx.cwd },
        );
        if (code !== 0 || !stashRef.trim()) {
          ctx.ui.notify("Nothing to checkpoint (clean working tree)", "info");
          return;
        }
        const { stdout: log } = await pi.exec(
          "git",
          ["log", "--oneline", "-1"],
          { cwd: ctx.cwd },
        );
        checkpoints.push({
          stashRef: stashRef.trim(),
          entryId: currentEntryId || "unknown",
          timestamp: Date.now(),
          description: log.trim() || "manual checkpoint",
        });
        ctx.ui.notify(
          `Checkpoint created (${stashRef.trim().slice(0, 8)})`,
          "info",
        );
      } else if (subcommand === "restore") {
        if (checkpoints.length === 0) {
          ctx.ui.notify("No checkpoints to restore", "warning");
          return;
        }
        const options = checkpoints.map((cp, i) => ({
          label: `[${i + 1}] ${new Date(cp.timestamp).toLocaleTimeString()} - ${cp.description}`,
          value: String(i),
        }));
        const choice = await ctx.ui.select(
          "Select checkpoint to restore:",
          options,
        );
        if (!choice) return;

        const idx = parseInt(choice, 10);
        const cp = checkpoints[idx];
        if (!cp) return;

        const { code } = await pi.exec("git", ["stash", "apply", cp.stashRef], {
          cwd: ctx.cwd,
        });
        if (code === 0) {
          ctx.ui.notify(
            `Restored checkpoint from ${new Date(cp.timestamp).toLocaleTimeString()}`,
            "info",
          );
        } else {
          ctx.ui.notify("Failed to restore checkpoint (conflicts?)", "warning");
        }
      } else {
        ctx.ui.notify("Usage: /checkpoint [list|create|restore]", "info");
      }
    },
  });
}
