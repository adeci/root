---
name: root-repo
description: How to work in the root infrastructure repo at $HOME/git/root. Use when making changes to NixOS configs, home-manager modules, clan services, or anything in the repo. Covers verification workflow, where to put things, and common pitfalls. For pi agent config (skills, extensions, prompts, agents), use the manage-pi skill instead.
---

# Root Repo

## Environment

Nix is always available. The devshell adds `clan` and `tofu`:

```bash
nix develop -c <command>    # Run a single command in the devshell
nix develop                 # Enter interactively
hostname                    # Check which machine you're on
```

## Verification Workflow

Every change follows this sequence:

```bash
cd $HOME/git/root
git add <new-files>                   # Flake can't see untracked files
nix fmt                               # Format everything
git add -u                            # Stage formatting changes
nix eval .#nixosConfigurations.$(hostname).config.system.build.toplevel  # Fast eval check
```

For a full build (slower, catches more): replace `nix eval` with `nix build`.
For Darwin: `nix build .#darwinConfigurations.malum.system`.

To inspect home-manager file outputs:

```bash
nix eval .#nixosConfigurations.$(hostname).config.home-manager.users.alex.home.file \
  --apply 'f: builtins.attrNames f' --json
```

**Never deploy.** Tell Alex when changes are ready — he pushes with
`clan machines update`.

## Where to Put Things

### Pi Agent Config (skills, extensions, prompts, agents)

Use the `manage-pi` skill — it has full details and templates.

### NixOS Modules

`modules/nixos/<name>.nix` — auto-discovered. Use `adeci.*` option namespace.
Enable in the machine's `configuration.nix`.

### Home-Manager Modules

`modules/home-manager/<name>.nix` (or `<name>/default.nix`) — auto-discovered.
Use `adeci.*` namespace. Enable via a profile in `profiles/home-manager/`, then
assign profiles to users/machines through the roster.

### Clan Services

`clan-services/<name>/` with `@adeci/<name>` naming. Instance config goes in
`clan-inventory/instances/`. Target machines via tags.

## Reference Material

Pi documentation and extension examples live in the pi-mono repo:
`https://github.com/badlogic/pi-mono` — use the `browse-repos` skill to clone
it locally if you need to reference docs or examples.

Key docs: `docs/extensions.md`, `docs/skills.md`, `docs/tui.md`
Examples: `packages/coding-agent/examples/extensions/` (50+ working examples)
