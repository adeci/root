# Pi Coding Agent — Planning & Research

## What is Pi?

Pi is a minimal terminal coding agent by Mario Zechner (badlogic). It lets an LLM
(Claude, GPT, Gemini, etc.) read code, edit files, and run commands — like Claude Code,
but designed as a bare framework you customize. Out of the box it does the basics. The
power comes from what you bolt on via extensions, skills, prompts, and packages.

**Source**: `github:badlogic/pi-mono` (MIT licensed)
**Site**: shittycodingagent.ai
**Install**: `npm install -g @mariozechner/pi-coding-agent` (or via numtide's `llm-agents.nix`)

Key differentiator: everything is toggleable at runtime. Extensions can be enabled/disabled
with `/command` toggles. Skills are loaded on-demand. You can switch models mid-session with
`/model` or `Ctrl+P`.

## Core Concepts

| Concept    | What                                                                                                                                                 | Where it lives                  | Loaded                           |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | -------------------------------- |
| Extensions | TypeScript modules hooking into pi's lifecycle events. Can register tools, commands, keyboard shortcuts, modify system prompt, intercept tool calls. | `~/.pi/agent/extensions/*.ts`   | Always (toggleable via commands) |
| Skills     | Markdown files with instructions + optional tool definitions. On-demand capability packages.                                                         | `~/.pi/agent/skills/*/SKILL.md` | On-demand (agent decides)        |
| Prompts    | Markdown templates accessible as `/name` slash commands. Reusable workflow recipes.                                                                  | `~/.pi/agent/prompts/*.md`      | On `/command` invocation         |
| Agents     | Markdown files defining sub-agents with different models/tools/roles. Used by swarm/subagent extensions.                                             | `~/.pi/agent/agents/*.md`       | By delegation extensions         |
| Packages   | Bundles of extensions + skills + prompts + themes.                                                                                                   | Installed via `pi install`      | Discovered automatically         |
| AGENTS.md  | Per-project instructions (pi's CLAUDE.md equivalent).                                                                                                | Project root or `~/.pi/agent/`  | Auto-discovered                  |

Everything under `~/.pi/agent/` is global. Per-project overrides go in `.agent/` or
`.pi/` in the project root.

## Extension API Surface

Extensions are TypeScript files exporting a default function that receives `pi: ExtensionAPI`.

### Events you can hook into

| Event                        | When                            | What you can do                            |
| ---------------------------- | ------------------------------- | ------------------------------------------ |
| `session_start`              | Session initialized             | Set up state, show status widgets          |
| `before_agent_start`         | Before first LLM turn           | Modify/append to system prompt             |
| `turn_start`                 | Before each user turn processed | Create checkpoints, inject context         |
| `turn_end`                   | After LLM responds              | Track state, update UI                     |
| `agent_end`                  | LLM done, waiting for input     | Send notifications                         |
| `tool_call`                  | Before a tool executes          | Block/modify tool calls (permission gates) |
| `input`                      | User types something            | Transform/intercept input                  |
| `session_before_compact`     | Before context compaction       | Custom summarization                       |
| `resources_discover`         | Resource loading                | Provide skill/prompt/theme paths           |
| `session_shutdown`           | Cleanup                         | Save state                                 |
| `session_before_switch/fork` | Before branching                | Block with `{ cancel: true }`              |

### What you can register

- `pi.registerTool()` — custom tools the LLM can call
- `pi.registerCommand()` — `/slash` commands for the user
- `pi.registerShortcut()` — keyboard shortcuts
- `pi.registerProvider()` — custom model providers
- `pi.registerFlag()` — CLI flags

### Context access

- `ctx.ui.notify()`, `ctx.ui.select()`, `ctx.ui.confirm()` — UI interactions
- `ctx.ui.setStatus()` — status bar widgets
- `ctx.exec()` — run shell commands
- `ctx.sessionManager` — access conversation history
- `pi.sendUserMessage()` — inject messages into conversation
- `pi.events.emit()` — inter-extension communication

## Current Setup in This Repo

We pull pi from numtide's `llm-agents.nix` flake (`flake.nix:27-29`):

```nix
llm-agents.url = "github:numtide/llm-agents.nix";
```

The home-manager module at `modules/home-manager/llm-tools.nix` installs three packages:
`pi`, `claude-code`, `ccusage`. Gated behind `adeci.llm-tools.enable`, activated in the
`llm-tools` profile for the `alex` user.

**No pi configuration exists yet** — no extensions, skills, prompts, or settings.

---

## Research: How Others Set Up Pi

### Surma (surma-nixenv) — Pure home-manager `home.file`

**Approach**: Fully declarative Nix. All pi config managed via `home.file` entries.

**Module structure**:

- `modules/features/pi.nix` — top-level option + package install
- `modules/home-manager/pi/default-config.nix` — writes `models.json` via `home.file.text`
- `modules/programs/pi/superpowers/default.nix` — auto-discovers and symlinks skills/extensions from `pi-superpowers` flake input
- `modules/programs/pi/napkin/default.nix` — symlinks a local custom skill

**Key pattern** — auto-discover from flake input with `builtins.readDir`:

```nix
superpowers = inputs.pi-superpowers;

mkLinks = base: entries:
  mapAttrs' (name: type:
    nameValuePair ".pi/agent/${base}/${name}" {
      source = "${superpowers}/${base}/${name}";
    }
  ) (filterAttrs (_: type: builtins.elem type ["regular" "directory"]) entries);

skillLinks = mkLinks "skills" (builtins.readDir "${superpowers}/skills");
extensionLinks = mkLinks "extensions" (builtins.readDir "${superpowers}/extensions");

home.file = mkMerge [ skillLinks extensionLinks ];
```

**Extensions**: All from `pi-superpowers` flake input (no custom local ones).

**Skills**: `pi-superpowers` skills + local `napkin` skill.

**Also runs**: Claude Code (wrapped with API key + MCP injection), OpenCode, full
self-hosted LiteLLM proxy routing through Anthropic/OpenAI/Google/Groq/xAI.

---

### Mic92 (mic92-dotfiles) — Homeshick + selective `home.file`

**Approach**: Raw dotfiles in git, symlinked wholesale by homeshick. `home.file` only
used for external flake inputs (mics-skills).

**Pi config stored directly in git** at `home/.pi/agent/`:

```
home/.pi/agent/
├── settings.json
├── extensions/
│   ├── custom-instructions.ts    # injects ~/.claude/CLAUDE.md into system prompt
│   ├── custom-footer.ts
│   ├── direnv.ts
│   ├── git-rebase-env.ts         # GIT_EDITOR=cat for non-interactive rebase
│   ├── permission-gate.ts        # blocks dangerous commands, toggleable
│   ├── questionnaire.ts
│   ├── slow-mode.ts
│   ├── stable-settings.ts        # prevents settings.json git noise
│   └── workmux-status.ts         # tmux status integration
└── prompts/
    ├── commit.md                  # smart commit messages (WHY not WHAT)
    ├── merge.md                   # commit → rebase → merge workflow
    ├── rebase.md                  # flexible rebase with conflict handling
    └── worktree.md                # parallel tasks in git worktrees
```

**settings.json**:

```json
{
  "lastChangelogVersion": "99.99.99",
  "followUpMode": "all",
  "theme": "light",
  "defaultProvider": "anthropic",
  "defaultModel": "claude-opus-4-6",
  "defaultThinkingLevel": "off",
  "skills": ["~/.claude/skills"],
  "compaction": { "enabled": true }
}
```

**Skills**: From `github:Mic92/mics-skills` flake input, linked via:

```nix
home.file.".claude/skills".source = "${inputs.mics-skills}/skills";
```

Provides: `context7-cli`, `pexpect-cli`, `kagi-search`, `screenshot-cli`, `db-cli`,
`gmaps-cli`, `browser-cli`.

**Also has**: Claude Code agents (codex, big-pickle, grok, gemini), Claude commands
(merge-when-green, simplify), PIM (sandboxed personal info manager using pi + haiku).

---

### Britton (brittonagentkit) — Standalone toolkit, manual symlinks

**Approach**: Dedicated repo for pi config. No Nix integration. Manual `ln -s` into
`~/.pi/agent/`.

**The most extensive setup of the three:**

**10 agents** (`_global/agents/`):

- `scout` (haiku) — fast read-only recon
- `worker` (sonnet) — full capability implementation
- `researcher` (opus) — deep analysis
- `planner` (sonnet) — task breakdown
- `reviewer` (sonnet) — code review
- `debugger` (sonnet) — bug tracing
- `tester` (sonnet) — test writing
- `refactorer` (sonnet) — safe restructuring
- `documenter` (sonnet) — docs/READMEs
- `verifier` (sonnet) — formal verification (Verus/Rust)

**15 extensions** (`_global/extensions/`):

- `safety-guards.ts` — blocks dangerous commands with confirmation
- `mode.ts` — unified Normal/Plan/Loop mode switcher (Alt+M / Ctrl+.)
- `swarm.ts` — multi-agent orchestration with TUI dashboard
- `git-checkpoint.ts` — git stash checkpoints before risky ops
- `git-dirty.ts` — rich git status in bottom bar (branch, ahead/behind, staged/modified)
- `direnv.ts` — auto-loads direnv environments
- `notify.ts` — desktop notifications on agent completion (OSC 777)
- `interactive-shell.ts` — drop into vim/htop mid-session
- `helix-editor.ts` — helix-style modal editing
- `handoff.ts` — context summaries for session handoff
- `context.ts` — token usage breakdown with `/context` command
- `auto-commit.ts` — auto-commit on session exit
- `file-trigger.ts` — watches file for external triggers
- `iroh-rpc.ts` — P2P agent-to-agent communication over QUIC
- `truncated-tool.ts` — proper output truncation for custom tools

**23 skills** (`_global/skills/`):

- `napkin` — per-repo learning file (tracks mistakes, corrections, patterns)
- `nix` — nix flakes/devshells/package management reference
- `clan`, `build`, `cloud`, `validate` — infra skills
- `tigerstyle` — coding philosophy (safety, performance, assertions)
- `ultra-mode` — maximum-effort mode with parallel sub-agents
- `git-worktree` — isolated worktree management
- `nix-prefetch-sri` — SRI hash fetching
- `kagi-search`, `context7-cli`, `browser-cli`, `screenshot-cli`, `pexpect-cli` — tool skills
- `gmaps-cli`, `db-cli`, `weather-cli` — utility skills
- `roster`, `tags`, `acl`, `vars` — domain-specific analysis skills
- `iroh-rpc` — P2P agent communication skill

**8 CLI tools** (`tools/`): Python + Rust tools packaged with Nix flake.

---

## Research: Pi-Mono Official Examples

The `packages/coding-agent/examples/extensions/` directory in pi-mono has **60+ reference
extensions**. These are NOT installed by default — they're examples to copy/adapt.

### Most commonly used (appear in multiple user configs)

| Extension                | What it does                                                                                                            | Used by                                  |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| `permission-gate.ts`     | Blocks dangerous bash commands (rm -rf, sudo, force push), prompts for confirmation. Toggleable via `/permission-gate`. | mic92, britton, surma (via superpowers)  |
| `notify.ts`              | Desktop notification when agent finishes (OSC 777/99/Windows toast).                                                    | mic92, britton, pi-mono example          |
| `git-checkpoint.ts`      | Creates git stash checkpoints at each turn. Offers restore on `/fork`.                                                  | britton, pi-mono example                 |
| `interactive-shell.ts`   | Lets you run interactive commands (`!vim`, `!htop`) by suspending TUI.                                                  | britton, pi-mono example                 |
| `auto-commit-on-exit.ts` | Auto-commits changes when session ends.                                                                                 | britton, pi-mono example                 |
| `plan-mode/`             | Claude Code-style plan mode (read-only exploration before implementation).                                              | britton (in `mode.ts`), pi-mono example  |
| `protected-paths.ts`     | Blocks writes to `.env`, `.git/`, `node_modules/`, etc.                                                                 | pi-mono example                          |
| `preset.ts`              | Named presets for model/thinking/tools/instructions. Switch with `/preset`.                                             | pi-mono example                          |
| `custom-compaction.ts`   | Replace default compaction with custom summarization.                                                                   | pi-mono example                          |
| `subagent/`              | Delegate tasks to specialized sub-agents with different models.                                                         | britton (as `swarm.ts`), pi-mono example |
| `tools.ts`               | Interactive `/tools` command to enable/disable tools at runtime.                                                        | pi-mono example                          |

### Custom extensions written by users (not in pi-mono)

| Extension                | What it does                                                                         | Used by        |
| ------------------------ | ------------------------------------------------------------------------------------ | -------------- |
| `custom-instructions.ts` | Injects `~/.claude/CLAUDE.md` into pi's system prompt at startup.                    | mic92, surma   |
| `stable-settings.ts`     | Resets `lastChangelogVersion` to `"99.99.99"` on session start to prevent git noise. | mic92, surma   |
| `git-rebase-env.ts`      | Sets `GIT_EDITOR=cat` and `GIT_SEQUENCE_EDITOR=cat` for non-interactive rebase.      | mic92, surma   |
| `workmux-status.ts`      | Updates tmux window status with agent state (working/waiting/done).                  | mic92, surma   |
| `direnv.ts`              | Loads direnv environment on session start and after bash commands.                   | mic92, britton |
| `git-dirty.ts`           | Rich git status in bottom bar (branch, ahead/behind, staged/modified counts).        | britton        |
| `context.ts`             | Shows context overview (window usage, extensions, skills, cost) via `/context`.      | britton        |
| `mode.ts`                | Unified Normal/Plan/Loop mode switcher.                                              | britton        |
| `swarm.ts`               | Multi-agent swarm orchestration with TUI dashboard.                                  | britton        |
| `helix-editor.ts`        | Helix-style modal editor in the TUI.                                                 | britton        |

---

## Research: Pi-Superpowers (jevon)

Installable pi package: `pi install git:github.com/jevon/pi-superpowers`

**2 extensions**:

- `prompt-user.ts` — lets the LLM ask the user questions (select, confirm, free text input)
- `todo-tracker/` — workflow-aware task list with status tracking (pending, in_progress, done, skipped, blocked), `/todos` TUI command

**8 skills** (workflow guides — markdown instructions, not code):

- `pi-superpowers` — meta-orchestrator that decides which skills to load per session
- `brainstorming` — structured ideation: understand → explore → present → save to `docs/plans/`
- `planning` — write detailed implementation plans, execute step-by-step with todo tracking
- `test-driven-development` — strict red-green-refactor enforcement ("no production code without a failing test first")
- `systematic-debugging` — 4-phase root cause investigation before any fix attempt
- `code-review` — self-review checklist + human feedback handling
- `git-workflow` — worktree-based isolated feature branches with setup/teardown
- `verification` — "no completion claims without fresh evidence" gate

Used by surma (via flake input with auto-discovery). Britton has his own versions of most
of these skills written from scratch.

---

## Plan: Home-Manager Integration

### Approach: Pure `home.file` (surma-style)

This fits our existing `adeci.*` module pattern. The module will:

1. Generate `settings.json` from Nix attrsets
2. Symlink local extension `.ts` files via `home.file.source`
3. Symlink local prompt `.md` files via `home.file.source`
4. Auto-discover and symlink external flake inputs (pi-superpowers, etc.)

### Settings

```json
{
  "lastChangelogVersion": "99.99.99",
  "defaultProvider": "anthropic",
  "defaultModel": "claude-opus-4-6",
  "defaultThinkingLevel": "off",
  "compaction": { "enabled": true }
}
```

Primary model: `claude-opus-4-6`. Secondary: `claude-sonnet-4-6` (swap with `/model` or
`Ctrl+P` at runtime).

### Phase 1 — Minimal (settings + core extensions)

Extensions to start with (the ones everyone agrees on):

| Extension            | Source          | Why                                                                                                      |
| -------------------- | --------------- | -------------------------------------------------------------------------------------------------------- |
| `permission-gate.ts` | mic92's version | Blocks rm -rf, force push, sudo, deploy, curl\|sh. Toggleable. The one extension literally everyone has. |
| `notify.ts`          | pi-mono example | Desktop notification when agent finishes. Simple, universally useful.                                    |
| `stable-settings.ts` | mic92's version | Prevents `settings.json` from changing on every session (git noise). Tiny.                               |
| `git-rebase-env.ts`  | mic92's version | Sets `GIT_EDITOR=cat` for non-interactive rebase. 3 lines.                                               |

These are small, battle-tested, and non-controversial. Total: ~170 lines of TypeScript.

### Phase 2 — Prompts (workflow shortcuts)

| Prompt    | Source | What it does                                                                      |
| --------- | ------ | --------------------------------------------------------------------------------- |
| `/commit` | mic92  | Commit staged changes with good message style (WHY not WHAT, imperative, concise) |
| `/rebase` | mic92  | Flexible rebase with smart argument parsing and conflict handling                 |

### Phase 3 — Skills via pi-superpowers

Add `pi-superpowers` as a `flake = false` input and auto-discover with `builtins.readDir`
(surma's pattern). This gives us 8 workflow skills + 2 extensions (prompt-user, todo-tracker)
for free.

### Phase 4 — Cherry-pick from brittonagentkit

Extensions worth considering once comfortable:

- `git-checkpoint.ts` — git stash safety net
- `git-dirty.ts` — rich git status in bottom bar
- `direnv.ts` — auto-load direnv environments
- `context.ts` — token usage visibility
- `interactive-shell.ts` — drop into vim/htop mid-session

Skills worth considering:

- `napkin` — per-repo learning file
- `nix` — nix reference material for the agent
- `clan` — clan CLI reference

### Phase 5 — Agents + multi-agent

Agent definitions for different model tiers:

- `scout` (sonnet 4.6) — fast read-only recon
- `worker` (opus 4.6) — full capability

Swarm extension for orchestrated multi-agent workflows.

---

## File Structure Target

After Phase 1, the home-manager module should produce:

```
~/.pi/agent/
├── settings.json                    # generated from Nix
├── extensions/
│   ├── permission-gate.ts           # symlinked from module
│   ├── notify.ts                    # symlinked from module
│   ├── stable-settings.ts           # symlinked from module
│   └── git-rebase-env.ts            # symlinked from module
├── prompts/                         # Phase 2
│   ├── commit.md
│   └── rebase.md
└── skills/                          # Phase 3 (from pi-superpowers flake input)
    ├── pi-superpowers/SKILL.md
    ├── brainstorming/SKILL.md
    ├── planning/SKILL.md
    ├── test-driven-development/SKILL.md
    ├── systematic-debugging/SKILL.md
    ├── code-review/SKILL.md
    ├── git-workflow/SKILL.md
    └── verification/SKILL.md
```

### Module Structure Target

```
modules/home-manager/
├── llm-tools.nix                    # existing — installs pi, claude-code, ccusage packages
└── pi/
    ├── default.nix                  # main module — settings.json + local extensions/prompts
    ├── extensions/
    │   ├── permission-gate.ts
    │   ├── notify.ts
    │   ├── stable-settings.ts
    │   └── git-rebase-env.ts
    └── prompts/
        ├── commit.md
        └── rebase.md
```

With a separate module for external skill sources (Phase 3):

```
modules/home-manager/pi/
└── superpowers.nix                  # auto-discovers from pi-superpowers flake input
```
