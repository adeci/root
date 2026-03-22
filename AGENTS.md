# AGENTS.md

Clan-based NixOS/Darwin infrastructure monorepo. Manages 9 machines
(8 NixOS, 1 Darwin) via declarative Nix configuration.

## System

NixOS. Use `nix run nixpkgs#<package>` or `nix-shell -p <package>` for
tools not in the dev shell. Enter the dev shell with `nix develop` or
`direnv allow`.

## Validate Changes

Always verify before considering work done:

```bash
# Format everything (required — CI will check this)
nix fmt

# Verify a specific machine evaluates
nix eval .#nixosConfigurations.<machine>.config.system.build.toplevel.drvPath

# Verify a Darwin machine
nix build .#darwinConfigurations.<machine>.system

# Verify standalone home-manager
nix build .#homeConfigurations.<name>.activationPackage
```

**Never run `clan machines update`** — deployment is a manual decision.

## Do Not Touch

- `sops/` and `vars/` — age-encrypted secrets. Don't modify, create,
  or decrypt these files.
- `flake.lock` — don't update inputs unless explicitly asked.
- `cloud/` — AWS infrastructure. Changes here have real cost implications.
- `facter.json` files — hardware facts, machine-generated.

## Directory Layout

```
flake.nix                        # Entry point (flake-parts)
flake-outputs/                   # Modular flake configuration
  clan.nix                       #   Clan orchestration
  dotpkgs.nix                    #   Wrapped tool packages
  home-configurations.nix        #   Standalone home-manager
  formatter.nix                  #   treefmt (nixfmt, shellcheck, deadnix, statix, prettier)
  devshell.nix                   #   Dev environment

clan-inventory/                  # What runs where (central truth)
  machines.nix                   #   Machine declarations + tags
  instances/                     #   Service role assignments (by tag)

clan-services/                   # Service definitions
  roster/                        #   User/group management (core service)
  tailscale/                     #   Mesh VPN
  vaultwarden/                   #   Password manager
  cloudflare-tunnel/             #   Tunnel ingress
  siteup/                        #   Web app deployment

machines/<name>/                 # Per-machine configs
  configuration.nix              #   NixOS/Darwin config (explicit module imports)
  home.nix                       #   Home-manager config (profile imports)
  disko.nix                      #   Disk partitioning
  facter.json                    #   Hardware facts (don't edit)
  modules/                       #   Machine-specific modules (only this machine)

modules/                         # Shared composable feature modules
  nixos/                         #   NixOS modules (portable capabilities)
  darwin/                        #   Darwin modules
  home-manager/                  #   Home-manager modules
    profiles/                    #   HM profile groupings (import sets of HM modules)

dotpkgs/                         # Wrapped tools (btop, kitty, starship, fuzzel, nixvim)
pkgs/                            # Custom package derivations
plans/                           # Planning documents (reference, not config)
```

## Key Concepts

**Inventory-driven**: `clan-inventory/machines.nix` declares machines with
tags. Services in `clan-inventory/instances/` are assigned to tags, not
individual machines. A machine gets a service by having the right tag.

**Explicit imports**: Modules are plain config files. Machine configs
import exactly what they need:

```nix
imports = [
  ../../modules/nixos/base.nix
  ../../modules/nixos/niri.nix
  ../../modules/nixos/laptop.nix
  ./modules/harmonia.nix          # machine-specific module
];
```

Home-manager uses per-machine `home.nix` files that import profiles:

```nix
imports = [
  ../../modules/home-manager/profiles/base.nix
  ../../modules/home-manager/profiles/desktop.nix
];
```

**Two kinds of modules**:

- `modules/nixos/` — shared, portable capabilities. Any machine could
  import these. Examples: `laptop.nix`, `gaming.nix`, `gpd-pocket-4/`.
  A module belongs here even if only one machine uses it today, as long
  as it describes a general capability rather than a specific machine's
  service configuration.

- `machines/<name>/modules/` — machine-specific config. Tightly coupled
  to one machine's deployment: its domains, its secrets, its service
  wiring. Examples: leviathan's harmonia signing keys, sequoia's
  buildbot master with its specific GitHub App and worker list.

**Clan services** come in two forms:

- **Built-in** (`input = "clan-core"`): Services shipped with clan-core.
  Used by creating an instance in `clan-inventory/instances/` that
  references them by name. No code in `clan-services/`. Examples:
  `syncthing`, `borgbackup`, `sshd`, `importer`.

- **Custom** (`input = "self"`): Services we define in `clan-services/`.
  They follow the Clan service module structure with
  `_class = "clan.service"`, manifest metadata, and role definitions.
  Registered in `clan-services/default.nix` with `@adeci/<name>` naming.
  See `clan-services/roster/default.nix` as the reference implementation.

**When to use a clan service vs a plain NixOS module:**

Use a **clan service** (built-in or custom) when:

- Multiple machines need coordinated config (shared secrets, device
  mesh, cross-machine references).
- `clan.core.vars` adds value for credential generation/distribution.
- The inventory's tag/machine assignment model fits naturally (assign
  by tag, override per-machine via settings).
- Examples: syncthing (auto device mesh via vars), roster (users across
  machines), borgbackup (client/server key exchange), sshd (certificate
  authority).

Use a **plain NixOS module** when:

- Config is self-contained to one machine or doesn't need cross-machine
  coordination.
- You're enabling a capability, not wiring machines together.
- The inventory indirection would add complexity without benefit.
- Examples: `laptop.nix` (power management), `gaming.nix` (Steam/GPU),
  `niri.nix` (compositor setup).

Prefer built-in clan services over writing custom ones when clan-core
already provides what you need.

**Roster**: The `@adeci/roster` service manages users (UIDs, groups,
sudo, SSH keys, passwords, shells) across machines. Users defined in
`clan-inventory/instances/roster/users.nix`, assigned to machines in
`roster/machines.nix`. Position hierarchy: `owner > admin > basic > service`.
Roster does NOT handle home-manager — that's per-machine `home.nix`.

## Code Conventions

- **Formatting**: `nix fmt` handles everything. Uses nixfmt for Nix,
  shellcheck for shell, deadnix + statix for Nix linting, prettier for
  markdown/json/yaml.
- **Naming**: Kebab-case for module and profile filenames. Service names
  use `@adeci/<name>`.
- **No custom option namespaces**: Don't create `adeci.*` or other custom
  options for wrapping upstream config. Modules are plain config —
  importing a module enables its features. The only `adeci.*` option is
  `adeci.primaryUser` which comes from roster. Configure upstream options
  directly (e.g., `services.buildbot-nix.master.*`, not a wrapper).
- **Commented-out imports**: Commented-out import lines in machine configs
  (e.g., `# ./modules/buildbot.nix`) are intentional — they indicate a
  module is ready but not yet deployed. Don't remove them.
- **Commented-out alternatives**: Commented-out lines next to active
  config (e.g., a previous URL or value) are intentional bookmarks for
  quick swapping — don't remove them.
- **No orphan files**: Everything must be `git add`ed before `nix build`
  will see it (flakes only see tracked files).

## Common Tasks

**Add a shared NixOS module**: Create `modules/nixos/<name>.nix` as plain
config. Import it in the relevant `machines/<name>/configuration.nix`.

**Add a machine-specific module**: Create
`machines/<name>/modules/<module>.nix` as plain config. Import it in
that machine's `configuration.nix` as `./modules/<module>.nix`.

**Add a home-manager module**: Create `modules/home-manager/<name>.nix`
(or `<name>/default.nix` for multi-file) as plain config. Add it to a
profile in `modules/home-manager/profiles/` or import directly in a
machine's `home.nix`.

**Add a machine**: Create `machines/<name>/configuration.nix`, add entry
to `clan-inventory/machines.nix` with tags, add user assignments in
`clan-inventory/instances/roster/machines.nix`.

**Add a clan service**: Create module in `clan-services/<name>/`, register
in `clan-services/default.nix`, create instance in
`clan-inventory/instances/<name>.nix`, assign roles to tags or machines.
Only use for multi-machine coordination where inventory assignment helps.

**Add a dotpkg**: Create directory in `dotpkgs/<name>/` with `module.nix`.
See `dotpkgs/README.md` for the wrapper pattern.
