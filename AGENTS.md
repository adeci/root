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

# Verify a specific NixOS machine evaluates
nix eval .#nixosConfigurations.<machine>.config.system.build.toplevel.drvPath

# Verify a Darwin machine (eval only — can't build cross-arch)
nix eval .#darwinConfigurations.<machine>.config.system.primaryUser

# Verify all checks for the current system
nix eval .#checks.x86_64-linux --json

# Verify terraform config builds
nix build .#packages.x86_64-linux.tf-plan --no-link
```

**Never run `clan machines update`** — deployment is a manual decision.

## Nix Tips

- Use `nix eval` instead of `nix flake show` to look up flake attributes.
- Use `--log-format bar-with-logs` with nix builds for better output.
- Don't use `nix flake check` on the whole flake — it tries to eval all
  systems including darwin which fails on linux builders. Use per-system
  eval instead.
- Use `nix run nixpkgs#<pkg>` or `nix shell nixpkgs#<pkg> -c` for
  tools not in the dev shell.
- When given a linter error, fix the root cause. Don't silence it.
- Shell scripts must pass `shellcheck` (enforced by treefmt).
- Read nix errors bottom-up. The last line is the actual problem,
  everything above is call stack.
- Use `pkgs.stdenv.hostPlatform.system` not `pkgs.system` (deprecated).

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
  resources/                     #   External resources we provision
    cloudflare/                  #     Cloudflare zones, tunnels, DNS records
    routeros/                    #     MikroTik device configs (switches, WAPs)
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
    nixvim.nix                   #     Nixvim standalone package
    wrapped.nix                  #     Wrapped packages (BirdeeHub nix-wrapper-modules)
    formatter.nix                #     treefmt config
    devshell.nix                 #     Dev environment
    checks.nix                   #     CI checks (auto-discovers NixOS + Darwin machines)
  clan/                          #   Custom clan service definitions (@adeci/*)
    tailscale/                   #     Mesh VPN
    harmonia/                    #     Binary cache (per-server signing keys)
    remote-builder/              #     Nix remote build offloading
    security-keys/               #     FIDO2 SSH key handle distribution
    siteup/                      #     Web app deployment
    trusted-caches/              #     External binary cache config
  terranix/                      #   Terraform modules (auto-discovered)
    backend.nix                  #     B2 backend + state encryption
    cloudflare.nix               #     Provider, tunnels, DNS records, zones
    routeros/                    #     MikroTik network infrastructure
      provider.nix               #       Providers, identity, fallback IPs, services
      switch.nix                 #       Bridge, ports, VLANs, PoE, mgmt VLAN interface
      wap.nix                    #       Per-VLAN bridges, WiFi stack
      models.nix                 #       Hardware specs (port counts per model)
      netinstall-*.nix           #       Per-model firmware flash packages
  nixos/                         #   NixOS modules (portable capabilities)
    base.nix                     #     Fleet-wide defaults (ssh, nix, locale, users)
    zsh.nix                      #     Wrapped zsh as login shell (+ LLM tools)
    desktop.nix                  #     Full desktop (niri, librewolf, audio, theming)
    librewolf.nix                #     LibreWolf with policies + browser-cli
    social.nix                   #     Communication apps (element, signal, vesktop)
    cloudflared.nix              #     Cloudflare tunnel connector
    ssh-tpm-agent.nix            #     TPM SSH agent (praxis only)
    cheat.nix                    #     Claude CLI helper (rbw-dependent machines)
    ...                          #     laptop, gaming, mullvad, yubikey, etc.
  darwin/                        #   Darwin modules
    base.nix                     #     Fleet-wide Darwin defaults + wrapped tools
    librewolf.nix                #     LibreWolf .app install + policies
    shopify.nix                  #     Work environment (1Password, tec, homebrew)
    karabiner.nix                #     Keyboard remapping config
    aerospace/                   #     Tiling window manager config
  wrapped/                       #   Wrapped packages (BirdeeHub nix-wrapper-modules)
    zsh.nix                      #     Shell + CLI tools (withLLMTools, extraInit)
    git.nix                      #     Git with baked-in config
    kitty.nix                    #     Terminal (uses login shell, decoupled from zsh)
    tmux.nix                     #     Terminal multiplexer
    btop.nix                     #     System monitor
    big-htop.nix                 #     htop configured for leviathan
    linux/                       #     Linux-only wrappers (excluded from darwin eval)
      niri.nix                   #       Wayland compositor (references kitty/noctalia by name from PATH)
      noctalia-shell.nix         #       Status bar
      desktop.nix                #       Self-contained desktop (niri + kitty + noctalia + zsh for demos)
  nixvim/                        #   Nixvim config (temporary — migrating to neovim 0.12)

machines/<name>/                 # Per-machine configs
  configuration.nix              #   NixOS/Darwin config (explicit module imports)
  terraform-configuration.nix    #   Terraform resources (auto-discovered)
  disko.nix                      #   Disk partitioning
  facter.json                    #   Hardware facts (don't edit)
  modules/                       #   Machine-specific modules (only this machine)
```

## Key Concepts

**Data vs logic**: Data lives in `inventory/` (users, resources, clan
assignments). Logic lives in `modules/` (flake-parts wiring, NixOS
modules, terraform modules). Flake-parts modules in `modules/flake-parts/`
bridge the two — they import data from `inventory/` and expose it
flake-wide on `self.*`.

**Wrapped packages**: CLI tools and desktop apps with config baked in
via [nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules).
Each wrapper in `modules/wrapped/` becomes a flake package
(`nix run .#<name>`). Wrappers are pure — no runtime file writes to
`$HOME`. Linux-only wrappers go in `modules/wrapped/linux/` and are
auto-excluded from darwin evaluation.

**Wrapper decoupling**: Wrappers are intentionally NOT nested into each
other on the system. Niri references kitty and noctalia-shell by name
(resolved from PATH at runtime), and kitty uses the login shell rather
than embedding a specific zsh store path. This means rebuilding
zsh/tmux/kitty takes effect in new terminals without restarting the
compositor. The `desktop` wrapper (`nix run .#desktop`) re-nests
everything into a self-contained package for demos.

`desktop.nix` adds wrapped kitty, noctalia-shell, and zsh (via
`lib.hiPrio` to win over the system zsh) to `environment.systemPackages`.

The zsh wrapper supports extension via `.wrap`:

```nix
# NixOS — enable LLM tools
zsh = self.packages.${pkgs.stdenv.hostPlatform.system}.zsh.wrap { withLLMTools = true; };

# Darwin — add extra shell init
shopifyZsh = zsh.wrap { extraInit = "eval \"$(tec init zsh)\""; };
```

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
```

**`self.resources`**: Shared resource data (Cloudflare zones, tunnels,
DNS records). Defined in `inventory/resources/`, exposed by
`modules/flake-parts/resources.nix`. Consumed by terraform modules and
NixOS modules via `self.resources.*`.

**Explicit imports**: Modules are plain config files. Machine configs
import exactly what they need:

```nix
# NixOS machine
imports = [
  self.users.alex.nixosModule
  ../../modules/nixos/base.nix
  ../../modules/nixos/desktop.nix
  ../../modules/nixos/zsh.nix
  ../../modules/nixos/laptop.nix
  ../../modules/nixos/cloudflared.nix
];

# Darwin machine
imports = [
  self.users.alex.darwinModule
  ../../modules/darwin/base.nix
  ../../modules/darwin/librewolf.nix
  ../../modules/darwin/shopify.nix
];
```

**Two kinds of modules**:

- `modules/nixos/` (or `modules/darwin/`) — shared, portable
  capabilities. Any machine could import these. Examples: `laptop.nix`,
  `gaming.nix`, `cloudflared.nix`, `desktop.nix`. A module belongs here
  even if only one machine uses it today, as long as it describes a
  general capability.

- `machines/<name>/modules/` — machine-specific config. Tightly coupled
  to one machine's deployment: its domains, its secrets, its service
  wiring. Examples: leviathan's buildbot config, sequoia's vaultwarden.

**SSH infrastructure**: FIDO2 YubiKeys + TPM for SSH authentication.

- YubiKey handles are distributed via the `@adeci/security-keys` clan
  service. Each machine declares which keys it uses (`settings.use`).
- TPM keys are machine-bound (praxis only). `ssh-tpm-agent` manages
  them via `SSH_AUTH_SOCK`.
- SSH priority: TPM agent (no touch) → FIDO2 handle files (YubiKey touch).
- Public keys (YubiKey + TPM) are in `inventory/users/alex.nix`.
- Desktop machines get `ssh-agent` via `desktop.nix` (`programs.ssh.startAgent`,
  `mkDefault` so `ssh-tpm-agent.nix` cleanly overrides it).
- Servers get no SSH agent (they're targets, not sources).
- `yubikey.nix` provides pcscd, udev rules, management tools, and
  `yubikey-touch-detector` for desktop notifications when touch is needed.
- `base.nix` configures SSH ControlMaster for Tailscale hosts
  (connection reuse, reduces FIDO2 touch prompts).

**Terranix infrastructure provisioning**: Cloud resources are managed
through Terranix (Nix → Terraform JSON → OpenTofu). All terraform
modules are auto-discovered and merged into one config.

- `modules/terranix/backend.nix` — Backblaze B2 state backend + encryption
- `modules/terranix/cloudflare.nix` — tunnels, DNS, zones (driven by
  `self.resources.cloudflare`)
- `machines/<name>/terraform-configuration.nix` — per-machine cloud
  resources (auto-discovered, e.g., conduit's Hetzner server)
- Credentials come from clan secrets via `data.external` at apply time
- Wrapper scripts: `nix run .#tf-{init,plan,apply,destroy}`

**RouterOS network infrastructure**: Physical network (switches, WAPs)
managed via a separate Terranix workspace. Device data lives in
`inventory/resources/routeros/`, logic in `modules/terranix/routeros/`.

- Two terraform workspaces: cloud (`tf-*`) and network (`net-*`) with
  separate state files in B2.
- `modules/terranix/routeros/switch.nix` — bridge, ports (access/trunk/
  hybrid), VLANs, PoE, management VLAN interfaces. Supports standalone
  trunk management: when `managementPort` is a trunk port, it stays out
  of the bridge with VLAN sub-interfaces feeding tagged traffic in
  (same architecture as WAPs). This enables one-shot terraform apply
  for switches with a single trunk uplink.
- `modules/terranix/routeros/wap.nix` — per-VLAN bridges, VLAN
  sub-interfaces on ether1, WiFi security/datapath/configuration
  profiles. Physical radio security is set inline (not just via profile
  reference) so changes to `security` in device configs take effect.
- `modules/terranix/routeros/provider.nix` — per-device providers,
  identity, fallback IPs, service hardening.
- Device provisioning: `nix run .#routeros-netinstall-<model>` flashes
  firmware + sets password + DHCP client. CRS310 script adds DHCP on
  both ether1 and sfp-sfpplus1 so it works plugged into either.
  Then `net-apply` configures everything.
- Wrapper scripts: `nix run .#net-{init,plan,apply,state}`
- `nix run .#net-state-rm-device` — bulk remove devices from state.
  Accepts multiple device names: `net-state-rm-device axon zephyr nimbus`.
- `machines/janus/modules/router.nix` — NixOS router (Qotom Q20321G9)
  with port map, VLAN sub-interfaces, br-mgmt bridge, nftables firewall
  (zone-based with Tailscale admin restrictions), dnsmasq DHCP/DNS, NAT.
- Janus advertises local subnets via Tailscale for remote management.
  `net-plan`/`net-apply` work from anywhere via Tailscale subnet routing.
- See `/home/alex/notes/netinfra.md` for full network documentation.

**Tailscale DNS and routing**: The `@adeci/tailscale` clan service handles
a known conflict between Tailscale subnet routing and local DNS. When a
machine with `accept-routes` is directly on an advertised subnet, DNS
breaks. The fix has three parts (all in `modules/clan/tailscale/`):

- `accept-dns = false` — prevents Tailscale from hijacking systemd-resolved.
- `services.resolved.dnsDelegates.tailscale` — systemd 258+ dns-delegate
  routes `.ts.net` queries to MagicDNS (100.100.100.100), independent of
  any network interface. `tailnet-domain` setting adds search domain for
  short hostname resolution.
- NetworkManager dispatcher adds `ip rule priority 5200 lookup main
  suppress_prefixlength 0` — prefers direct local routes over Tailscale's
  table 52. Priority 5200 is outside Tailscale's managed range (5210-5310).
- See `/home/alex/notes/tailnetwriteup.md` for full writeup.

**Cloudflare resources**: Zones, tunnels, and DNS records defined as
pure data in `inventory/resources/cloudflare/`. Terraform creates
tunnels + DNS records and pushes tokens to clan vars. The
`modules/nixos/cloudflared.nix` module enables cloudflared on machines
that have tunnels defined. Workflow: `tf-apply` → `clan machines update`.

**Clan services** come in two forms:

- **Built-in** (`input = "clan-core"`): Services shipped with clan-core.
  Examples: `syncthing`, `borgbackup`, `sshd`, `wifi`, `state-version`.

- **Custom** (`input = "self"`): Services we define in `modules/clan/`.
  They follow the Clan service module structure with
  `_class = "clan.service"`, manifest metadata, and role definitions.
  Registered in `modules/clan/default.nix` with `@adeci/<name>` naming.

Key patterns in custom services:

- Servers generate secrets, clients read public values via
  `clanLib.getPublicValue` (no generator needed on clients).
- Per-server signing keys (harmonia) — each server has its own keypair,
  clients collect all public keys.
- Per-client SSH keys (remote-builder) — each client generates a
  keypair, servers collect public keys.

**When to use terraform vs a clan service vs a plain NixOS module:**

Use **terraform** when:

- Managing cloud/external resources (VMs, DNS, tunnels, buckets).
- The resource has an API, not an OS.

Use a **clan service** when:

- Multiple machines need coordinated config (shared secrets, key
  distribution, cross-machine references).

Use a **plain NixOS/Darwin module** when:

- Config is self-contained to one machine or doesn't need cross-machine
  coordination.

**Chrysalis**: Custom installer machine (`machines/chrysalis/`). Flash
to USB with `clan flash write chrysalis --disk main /dev/sdX`. SSH keys,
wifi, and harmonia cache are baked in.

## Code Conventions

- **Formatting**: `nix fmt` handles everything. Uses nixfmt for Nix,
  shellcheck for shell, deadnix + statix for Nix linting, prettier for
  markdown/json/yaml.
- **Naming**: Kebab-case for module filenames. Service names use
  `@adeci/<name>`. Terraform config files use
  `terraform-configuration.nix`.
- **No custom option namespaces**: Don't create custom options for
  wrapping upstream config. Modules are plain config — importing a
  module enables its features. Configure upstream options directly.
- **No home-manager**: All machines use wrapped packages + NixOS/Darwin
  modules. No `home.file`, no `programs.*` from HM, no `home.nix`.
- **Shell language hints**: Use `# bash` or `# zsh` comments before
  long multiline shell strings for editor syntax highlighting:
  ```nix
  script = # bash
    ''
      echo "highlighted as bash"
    '';
  ```
- **Commented-out imports**: Commented-out import lines in machine configs
  are intentional — they indicate a module is ready but not yet deployed.
- **Commented-out alternatives**: Commented-out lines next to active
  config are intentional bookmarks for quick swapping.
- **No orphan files**: Everything must be `git add`ed before `nix build`
  will see it (flakes only see tracked files).

## Common Tasks

**Add a user**: Create `inventory/users/<name>.nix` with uid, shell,
groups, sshKeys. It's auto-discovered. Import
`self.users.<name>.nixosModule` in machine configs that need the user.

**Add a shared NixOS module**: Create `modules/nixos/<name>.nix` as plain
config. Import it in the relevant `machines/<name>/configuration.nix`.

**Add a shared Darwin module**: Create `modules/darwin/<name>.nix`. Import
in `machines/malum/configuration.nix`. Homebrew taps/casks/brews go in
the module that needs them (not a central homebrew.nix).

**Add a wrapped package**: Create `modules/wrapped/<name>.nix` (or
`modules/wrapped/linux/<name>.nix` for linux-only). It's auto-discovered
and becomes a flake package. Use `wlib.modules.default` for the common
wrapper pattern, or `wlib.wrapperModules.<name>` for upstream modules.

**Add a machine-specific module**: Create
`machines/<name>/modules/<module>.nix`. Import it in that machine's
`configuration.nix` as `./modules/<module>.nix`.

**Add a machine**: Create `machines/<name>/configuration.nix`, add entry
to `inventory/clan/machines.nix` with tags.

**Add a clan service**: Create module in `modules/clan/<name>/`, register
in `modules/clan/default.nix`, create instance in
`inventory/clan/instances/<name>.nix`, assign roles to tags or machines.

**Add a Cloudflare tunnel**: Add machine + ingress rules to
`inventory/resources/cloudflare/tunnels.nix`. Import
`modules/nixos/cloudflared.nix` in the machine config. Run
`nix run .#tf-apply` then `clan machines update <machine>`.

**Add terraform resources**: For machine-coupled infra, create
`machines/<name>/terraform-configuration.nix` (auto-discovered). For
shared resources, create a file in `modules/terranix/` (auto-discovered).
Run `nix run .#tf-init` if new providers, then `nix run .#tf-apply`.

**Add a RouterOS device**: Create `inventory/resources/routeros/<name>.nix`
with model, host, VLANs/WiFi config. Add to registry in
`inventory/resources/routeros/default.nix`. Netinstall first
(`nix run .#routeros-netinstall-<model>`), plug into switch, get MAC
from janus DHCP leases, add static lease to `router.nix`, then
`nix run .#net-apply`. See `/home/alex/notes/netinfra.md` for details.

**Flash the installer**: `clan flash write chrysalis --disk main /dev/sdX`.
SSH keys, wifi, and harmonia cache are baked in — no flags needed.
