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

# Verify a Darwin machine (eval only — can't build cross-arch)
nix eval .#darwinConfigurations.<machine>.config.system.primaryUser

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
- Read nix errors bottom-up. The last line is the actual problem,
  everything above is call stack.

## Do Not Touch

- `sops/` and `vars/` — age-encrypted secrets. Don't modify, create,
  or decrypt these files.
- `flake.lock` — don't update inputs unless explicitly asked.
- `facter.json` files — hardware facts, machine-generated.

## Directory Layout

```
flake.nix                        # Entry point (flake-parts)

inventory/                       # What we manage — data, not logic
  users/                         #   User definitions (self.users.*)
    default.nix                  #     Auto-discovers per-user files
    alex.nix                     #     Per-user data (uid, keys, groups, shell)
    brittonr.nix
    ...
  resources/                     #   External resources we provision
    cloudflare-tunnels.nix       #     Tunnel definitions (drives terraform + NixOS)
  clan/                          #   Clan-specific inventory
    default.nix                  #     Inventory loader
    machines.nix                 #     Machine declarations + tags
    instances/                   #   Clan service role assignments (by tag)

modules/                         # Shared composable modules — logic, not data
  flake-parts/                   #   Flake-level wiring
    flake-module.nix             #     Hub — imports all flake-parts modules
    users.nix                    #     Wraps inventory/users/ with mkUser → self.users
    resources.nix                #     Exposes inventory/resources/ → self.resources
    clan.nix                     #     Clan orchestration
    terranix.nix                 #     Terraform wrapper scripts + auto-discovery
    packages.nix                 #     Custom packages
    home-configurations.nix      #     Standalone home-manager
    formatter.nix                #     treefmt config
    devshell.nix                 #     Dev environment
    checks.nix                   #     CI checks
  clan/                          #   Custom clan service definitions (@adeci/*)
    tailscale/                   #     Mesh VPN
    harmonia/                    #     Binary cache
    remote-builder/              #     Nix remote build offloading
    siteup/                      #     Web app deployment
    trusted-caches/              #     External binary cache config
  terranix/                      #   Terraform modules
    base.nix                     #     B2 backend + state encryption
    cloudflare.nix               #     Provider, tunnels, DNS records, zones
  nixos/                         #   NixOS modules (portable capabilities)
    base.nix                     #     Fleet-wide defaults (ssh, nix, locale, users)
    cloudflared.nix              #     Cloudflare tunnel connector
  darwin/                        #   Darwin modules
  home-manager/                  #   Home-manager modules
    profiles/                    #     HM profile groupings

machines/<name>/                 # Per-machine configs
  configuration.nix              #   NixOS/Darwin config (explicit module imports)
  terraform-configuration.nix    #   Terraform resources (auto-discovered)
  home.nix                       #   Home-manager config (profile imports)
  disko.nix                      #   Disk partitioning
  facter.json                    #   Hardware facts (don't edit)
  modules/                       #   Machine-specific modules (only this machine)

packages/                        # Custom package derivations
  wrapped/                       #   Wrapped tools (btop, kitty, starship, fuzzel, nixvim)
```

## Key Concepts

**Data vs logic**: Data lives in `inventory/` (users, resources, clan
assignments). Logic lives in `modules/` (flake-parts wiring, NixOS
modules, terraform modules). Flake-parts modules in `modules/flake-parts/`
bridge the two — they import data from `inventory/` and expose it
flake-wide on `self.*`.

**`self.users`**: User definitions available everywhere in the flake.
Each user has `.username`, `.uid`, `.sshKeys`, `.groups`, `.shell`, plus
`.nixosModule` and `.darwinModule` for creating the account on a machine.
Defined in `inventory/users/`, wrapped by `modules/flake-parts/users.nix`.

```nix
# Machine config — import users you want on this machine
imports = [
  self.users.alex.nixosModule
  self.users.dima.nixosModule
];

# Terraform — reference user data directly
resource.hcloud_ssh_key.alex = {
  public_key = builtins.head self.users.alex.sshKeys;
};
```

**`self.resources`**: Shared resource data (tunnels, future B2 buckets,
routeros configs). Defined in `inventory/resources/`, exposed by
`modules/flake-parts/resources.nix`. Consumed by terraform modules and
NixOS modules via `self.resources.*`.

**Explicit imports**: Modules are plain config files. Machine configs
import exactly what they need:

```nix
imports = [
  self.users.alex.nixosModule
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
modules merge into one config with shared B2 backend.

- `modules/terranix/base.nix` — Backblaze B2 state backend + encryption
- `modules/terranix/cloudflare.nix` — tunnels, DNS, zones (driven by
  `self.resources.tunnels`)
- `machines/<name>/terraform-configuration.nix` — per-machine cloud
  resources (auto-discovered, e.g., conduit's Hetzner server)
- Credentials come from clan secrets via `data.external` at apply time
- Wrapper scripts: `nix run .#tf-{init,plan,apply,destroy}`

**Cloudflare tunnels**: Defined in `inventory/resources/cloudflare-tunnels.nix`
(single source of truth). Exposed as `self.resources.tunnels`. Terraform
creates tunnels + DNS records and pushes tokens to clan vars via
`local-exec`. The `modules/nixos/cloudflared.nix` module reads
`self.resources.tunnels` and enables cloudflared on machines that have
tunnels defined. Workflow: `tf-apply` → `clan machines update <machine>`.

**Clan services** come in two forms:

- **Built-in** (`input = "clan-core"`): Services shipped with clan-core.
  Used by creating an instance in `inventory/clan/instances/` that
  references them by name. No code in `modules/clan/`. Examples:
  `syncthing`, `borgbackup`, `sshd`, `wifi`, `state-version`.

- **Custom** (`input = "self"`): Services we define in `modules/clan/`.
  They follow the Clan service module structure with
  `_class = "clan.service"`, manifest metadata, and role definitions.
  Registered in `modules/clan/default.nix` with `@adeci/<name>` naming.

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
- **No custom option namespaces**: Don't create custom options for
  wrapping upstream config. Modules are plain config — importing a
  module enables its features. Configure upstream options directly
  (e.g., `services.buildbot-nix.master.*`, not a wrapper).
- **Commented-out imports**: Commented-out import lines in machine configs
  (e.g., `# ./modules/buildbot.nix`) are intentional — they indicate a
  module is ready but not yet deployed. Don't remove them.
- **Commented-out alternatives**: Commented-out lines next to active
  config (e.g., a previous URL or value) are intentional bookmarks for
  quick swapping — don't remove them.
- **No orphan files**: Everything must be `git add`ed before `nix build`
  will see it (flakes only see tracked files).

## Common Tasks

**Add a user**: Create `inventory/users/<name>.nix` with uid, shell,
groups, sshKeys. It's auto-discovered. Import
`self.users.<name>.nixosModule` in machine configs that need the user.

**Add a user to a machine**: Add `self.users.<name>.nixosModule` to the
machine's `configuration.nix` imports. For Darwin, use
`self.users.<name>.darwinModule`.

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
to `inventory/clan/machines.nix` with tags.

**Add a clan service**: Create module in `modules/clan/<name>/`, register
in `modules/clan/default.nix`, create instance in
`inventory/clan/instances/<name>.nix`, assign roles to tags or machines.
Only use for multi-machine coordination where inventory assignment helps.

**Add a Cloudflare tunnel**: Add machine + ingress rules to
`inventory/resources/cloudflare-tunnels.nix`. Import
`modules/nixos/cloudflared.nix` in the machine's `configuration.nix`.
Run `nix run .#tf-apply` then `clan machines update <machine>`.

**Add terraform resources**: For machine-coupled infra, create
`machines/<name>/terraform-configuration.nix` (auto-discovered). For
shared resources, add to or create a file in `modules/terranix/`. Run
`nix run .#tf-init` if new providers are needed, then
`nix run .#tf-apply`.

**Flash the installer**: `clan flash write chrysalis --disk main /dev/sdX`.
SSH keys, wifi, and harmonia cache are baked in — no flags needed.
