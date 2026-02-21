# Napkin

## Corrections

| Date       | Source | What Went Wrong                               | What To Do Instead                                                                                        |
| ---------- | ------ | --------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| 2026-02-20 | self   | Copied files directly to ~/.pi/agent/         | ~/.pi/agent/ is symlinked from home-manager. Put files in modules/home-manager/pi/ and update default.nix |
| 2026-02-20 | self   | Placed a plan file in .github/ without asking | Plans/proposals go in plans/. Ask where files should go before creating them.                             |
| 2026-02-21 | user   | Wrote playbook saying "delegate by default"   | Delegate when parallelism helps, do single tasks yourself. Don't over-delegate.                           |
| 2026-02-21 | self   | Workers used sed/grep instead of read/edit    | Worker prompt was too vague. Explicitly tell workers what tools they have and to prefer read/edit/write.  |

## Repo-Specific Rules

- ALWAYS read the `root-repo` skill before touching ANY file in this repo
- When the task involves pi agent config, also read `manage-pi` skill
- New top-level files in modules/home-manager/pi/ need explicit entries in default.nix — auto-discovery only handles subdirectories
- Conditional fish functions via `lib.mkIf config.adeci.<module>.enable`

## Agent Architecture (2026-02-21)

- Thinking levels: haiku/sonnet support off/minimal/low/medium/high. xhigh is opus only.
- No haiku-4-6 yet, latest haiku is haiku-4-5
- pi supports `--thinking <level>` flag and `model:thinking` shorthand
- Subagent extension spawns `pi -p` processes. Widget via `ctx.ui.setWidget` for live status.
- `ctx.hasUI` is false in print mode, so widgets only work in interactive orchestrator sessions
- Extensions load via jiti, can test with `pi -e path/to/ext.ts` without compiling
- Can test extension loading with `-p` mode but can't see TUI rendering

## Patterns That Work

- Dispatching workers in parallel for independent tasks with labels
- Workers self-scouting via `pi -p --model claude-haiku-4-5 --tools read,bash --no-extensions --no-skills --no-session`
- Testing extension changes with `pi -p -e path/to/extension.ts`

## Patterns That Don't Work

- Rigid scout → planner → worker chains. Worker re-reads files anyway, lossy compression at each handoff.
- Single worker handling multiple unrelated tasks sequentially. Context bloat, no parallelism.
- Pre-scouting before workers start. Workers know what they need better than an upfront scout.
- Models casually override `thinking` param on subagent tool calls. Added "Do NOT set unless explicitly asked" to schema descriptions. Watch for this recurring.

## Domain Notes

- pi agent config source of truth: modules/home-manager/pi/
- Extensions from pi-mono examples can be copied and adapted locally
- pi-mono cloned at ~/git/pi-repos/badlogic--pi-mono
- TUI components: Text, Container, Markdown, Spacer from @mariozechner/pi-tui
- Theme colors are typed (ThemeColor union), but raw ANSI codes work fine in Text components
