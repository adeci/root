# AGENTS.md

Clan-based NixOS/Darwin infrastructure monorepo. Manages 10 machines
(9 NixOS, 1 Darwin) via declarative Nix configuration with Terranix
for cloud provisioning.

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

# Verify terraform config builds
nix build .#packages.x86_64-linux.tf-plan --no-link
```

**Never run `clan machines update`** — deployment is a manual decision.

## Nix Tips

- Use `nix eval` instead of `nix flake show` to look up flake attributes.
- Use `--log-format bar-with-logs` with nix builds for better output.
- Don't use `nix flake check` on the whole flake — it's too slow.
  Build individual checks instead.
- Use `nix run nixpkgs#<pkg>` or `nix shell nixpkgs#<pkg> -c` for
  tools not in the dev shell.
- When given a linter error, fix the root cause. Don't silence it.
- Shell scripts must pass `shellcheck` (enforced by treefmt).

## Do Not Touch

- `sops/` and `vars/` — age-encrypted secrets. Don't modify, create,
  or decrypt these files.
- `flake.lock` — don't update inputs unless explicitly asked.
- `facter.json` files — hardware facts, machine-generated.

## Directory Layout

```
flake.nix                        # Entry point (flake-parts)

modules/                         # Shared composable modules
  flake-parts/                   #   Flake-level wiring (Enzime-style)
    flake-module.nix             #     Hub — imports all flake-parts modules
    clan.nix                     #     Clan orchestration
    terranix.nix                 #     Terraform wrapper scripts + config eval
    packages.nix                 #     Custom packages
    home-configurations.nix      #     Standalone home-manager
    formatter.nix                #     treefmt config
    devshell.nix                 #     Dev environment
    checks.nix                   #     CI checks
  clan/                          #   Custom clan service definitions (@adeci/*)
    roster/                      #     User/group management
    tailscale/                   #     Mesh VPN
    harmonia/                    #     Binary cache
    remote-builder/              #     Nix remote build offloading
    siteup/                      #     Web app deployment
    trusted-caches/              #     External binary cache config
  terranix/                      #   Shared terraform modules
    base.nix                     #     B2 backend + state encryption
    cloudflare.nix               #     Tunnels, DNS records, zones
  nixos/                         #   NixOS modules (portable capabilities)
    cloudflared.nix              #     Cloudflare tunnel connector (reads tunnels.nix)
  darwin/                        #   Darwin modules
  home-manager/                  #   Home-manager modules
    profiles/                    #     HM profile groupings

inventory/                       # What runs where (central truth)
  machines.nix                   #   Machine declarations + tags
  tunnels.nix                    #   Cloudflare tunnel definitions (shared by
                                 #     terraform + NixOS cloudflared module)
  instances/                     #   Clan service role assignments (by tag)

machines/<name>/                 # Per-machine configs
  configuration.nix              #   NixOS/Darwin config (explicit module imports)
  terraform-configuration.nix    #   Terraform resources for this machine (optional)
  home.nix                       #   Home-manager config (profile imports)
  disko.nix                      #   Disk partitioning
  facter.json                    #   Hardware facts (don't edit)
  modules/                       #   Machine-specific modules (only this machine)

packages/                        # Custom package derivations
  wrapped/                       #   Wrapped tools (btop, kitty, starship, fuzzel, nixvim)
```

## Key Concepts

**Inventory-driven**: `inventory/machines.nix` declares machines with
tags. Services in `inventory/instances/` are assigned to tags, not
individual machines. A machine gets a service by having the right tag.

**Explicit imports**: Modules are plain config files. Machine configs
import exactly what they need:

```nix
imports = [
  ../../modules/nixos/base.nix
  ../../modules/nixos/niri.nix
  ../../modules/nixos/laptop.nix
  ../../modules/nixos/cloudflared.nix
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
  import these. Examples: `laptop.nix`, `gaming.nix`, `cloudflared.nix`.
  A module belongs here even if only one machine uses it today, as long
  as it describes a general capability rather than a specific machine's
  service configuration.

- `machines/<name>/modules/` — machine-specific config. Tightly coupled
  to one machine's deployment: its domains, its secrets, its service
  wiring. Examples: leviathan's buildbot config, sequoia's vaultwarden
  with its specific domains and reverse proxy setup.

**Terranix infrastructure provisioning**: Cloud resources are managed
through Terranix (Nix → Terraform JSON → OpenTofu). All terraform
modules merge into one "everything" config with shared B2 backend.

- `modules/terranix/base.nix` — Backblaze B2 state backend + encryption
- `modules/terranix/cloudflare.nix` — tunnels, DNS, zones (driven by
  `inventory/tunnels.nix`)
- `machines/<name>/terraform-configuration.nix` — per-machine cloud
  resources (e.g., conduit's Hetzner server)
- Providers are declared alongside the resources that use them
- Credentials come from clan secrets via `data.external` at apply time
- Wrapper scripts: `nix run .#tf-{init,plan,apply,destroy}`

**Cloudflare tunnels**: Defined in `inventory/tunnels.nix` (single
source of truth). Terraform creates tunnels + DNS records and pushes
tokens to clan vars via `local-exec`. The `modules/nixos/cloudflared.nix`
module reads `tunnels.nix` and enables cloudflared on machines that have
tunnels defined. Workflow: `tf-apply` → `clan machines update <machine>`.

**Clan services** come in two forms:

- **Built-in** (`input = "clan-core"`): Services shipped with clan-core.
  Used by creating an instance in `inventory/instances/` that references
  them by name. No code in `modules/clan/`. Examples: `syncthing`,
  `borgbackup`, `sshd`, `wifi`, `state-version`.

- **Custom** (`input = "self"`): Services we define in `modules/clan/`.
  They follow the Clan service module structure with
  `_class = "clan.service"`, manifest metadata, and role definitions.
  Registered in `modules/clan/default.nix` with `@adeci/<name>` naming.
  See `modules/clan/roster/default.nix` as the reference implementation.

**When to use terraform vs a clan service vs a plain NixOS module:**

Use **terraform** when:

- Managing cloud/external resources (VMs, DNS, tunnels, buckets).
- The resource has an API, not an OS — you provision it, not deploy to it.
- Cross-resource references are needed (DNS record → server IP).

Use a **clan service** when:

- Multiple machines need coordinated config (shared secrets, device
  mesh, cross-machine references).
- `clan.core.vars` adds value for credential generation/distribution.
- The inventory's tag/machine assignment model fits naturally.

Use a **plain NixOS module** when:

- Config is self-contained to one machine or doesn't need cross-machine
  coordination.
- You're enabling a capability, not wiring machines together.

**Roster**: The `@adeci/roster` service manages users (UIDs, groups,
sudo, SSH keys, passwords, shells) across machines. Users defined in
`inventory/instances/roster/users.nix`, assigned to machines in
`roster/machines.nix`. Position hierarchy: `owner > admin > basic > service`.
Roster does NOT handle home-manager — that's per-machine `home.nix`.

**Chrysalis**: Custom installer machine (`machines/chrysalis/`). Imports
clan-core's installer module, adds our harmonia binary cache, tailscale,
wifi, and SSH keys. Flash to USB with `clan flash write chrysalis --disk main /dev/sdX`.

## Code Conventions

- **Formatting**: `nix fmt` handles everything. Uses nixfmt for Nix,
  shellcheck for shell, deadnix + statix for Nix linting, prettier for
  markdown/json/yaml.
- **Naming**: Kebab-case for module and profile filenames. Service names
  use `@adeci/<name>`. Terraform config files use
  `terraform-configuration.nix`.
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
to `inventory/machines.nix` with tags, add user assignments in
`inventory/instances/roster/machines.nix`.

**Add a clan service**: Create module in `modules/clan/<name>/`, register
in `modules/clan/default.nix`, create instance in
`inventory/instances/<name>.nix`, assign roles to tags or machines.
Only use for multi-machine coordination where inventory assignment helps.

**Add a Cloudflare tunnel**: Add machine + ingress rules to
`inventory/tunnels.nix`. Import `modules/nixos/cloudflared.nix` in the
machine's `configuration.nix`. Run `nix run .#tf-apply` then
`clan machines update <machine>`.

**Add terraform resources**: For machine-coupled infra, create
`machines/<name>/terraform-configuration.nix` and add it to the modules
list in `modules/flake-parts/terranix.nix`. For shared resources, add to
or create a file in `modules/terranix/`. Run `nix run .#tf-init` if new
providers are needed, then `nix run .#tf-apply`.

**Flash the installer**: `clan flash write chrysalis --disk main /dev/sdX`.
SSH keys, wifi, and harmonia cache are baked in — no flags needed.
