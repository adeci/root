---
name: manage-pi
description: Add, modify, or remove pi skills, extensions, prompts, and agents. Use whenever asked to create a new skill, write an extension, add a prompt template, define a subagent, or change any pi agent configuration — regardless of which repo you're currently working in.
---

# Manage Pi Config

All pi agent configuration is declaratively managed in the root repo and
deployed via home-manager. **Never write directly to `~/.pi/agent/`** — those
files are nix store symlinks.

## Location

```
~/git/root/modules/home-manager/pi/
├── default.nix              # Auto-discovers everything below
├── extensions/              # .ts files and directories with index.ts
│   ├── my-extension.ts      # Single-file extension
│   └── my-complex-ext/      # Multi-file extension
│       ├── index.ts
│       └── utils.ts
├── agents/                  # Subagent definitions (.md)
├── prompts/                 # Prompt templates (.md)
└── skills/                  # Skill directories
    └── my-skill/
        └── SKILL.md
```

## Adding a Skill

1. Create `~/git/root/modules/home-manager/pi/skills/<name>/SKILL.md`
2. Frontmatter must have `name` (matching directory) and `description`
3. Name rules: lowercase, hyphens only, 1-64 chars, no leading/trailing/consecutive hyphens

```markdown
---
name: my-skill
description: What it does and when to trigger it.
---

# My Skill

Instructions go here.
```

## Adding an Extension

Single file: `~/git/root/modules/home-manager/pi/extensions/my-ext.ts`

Multi-file: `~/git/root/modules/home-manager/pi/extensions/my-ext/index.ts`

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Events: session_start, turn_start, agent_end, tool_call, tool_result,
  //         before_agent_start, session_before_switch, session_before_fork
  // Register: registerCommand, registerTool, registerShortcut, registerFlag
  // State: setStatus, setModel, setThinkingLevel, setActiveTools, exec
}
```

Test before committing: `pi -e ~/git/root/modules/home-manager/pi/extensions/my-ext.ts`

## Adding an Agent

Create `~/git/root/modules/home-manager/pi/agents/<name>.md`:

```markdown
---
name: my-agent
description: What this agent does
tools: read, grep, find, ls
model: claude-haiku-4-5
---

System prompt for the agent.
```

## Adding a Prompt

Create `~/git/root/modules/home-manager/pi/prompts/<name>.md` with
`description` in frontmatter.

## Verification

Always run after changes:

```bash
cd ~/git/root
git add -A
nix fmt
git add -u
nix eval .#nixosConfigurations.$(hostname).config.system.build.toplevel
```

Then check the file will be deployed:

```bash
nix eval .#nixosConfigurations.$(hostname).config.home-manager.users.alex.home.file \
  --apply 'f: builtins.attrNames f' --json 2>&1 | tr ',' '\n' | grep '\.pi/agent'
```

## Important

- `default.nix` auto-discovers files — no manual wiring needed
- Never deploy — tell the user when changes are ready
- The user rebuilds with `clan machines update` or home-manager switch
