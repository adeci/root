# root

Personal infrastructure as code monorepo -- NixOS and Darwin machines managed with [Clan](https://clan.lol).

## Quick Start

```bash
nix develop          # or: direnv allow
clan machines list   # see what's here
nix fmt              # format everything
```

## Why Clan

Clan is a declarative infrastructure management framework built on NixOS and Nix flakes. It provides:

- **Inventory-driven service deployment** -- define services once, assign them to machines via tags, and Clan wires everything together.
- **Cross-platform support** -- manages both NixOS and Darwin (macOS) machines from a single flake.
- **Secrets management** -- built-in vars system for prompted secrets, encrypted with age and persisted automatically.
- **Reproducible deployments** -- every machine configuration is fully declarative and version-controlled.

## Architecture

```
flake.nix                   # entry point (flake-parts + clan-core)
flake-outputs/              # modular flake output definitions
  clan.nix                  #   clan config wiring
  dotpkgs.nix               #   package outputs
  home-configurations.nix   #   standalone home-manager
  formatter.nix             #   treefmt-nix rules
  devshell.nix              #   dev shell

clan-inventory/             # what runs where
  machines.nix              #   machine declarations + tags
  instances/                #   service -> machine assignments
    roster/                 #   user management config

clan-services/              # service definitions (@adeci/*)
  roster/                   #   users, groups, home-manager (cross-platform)
  tailscale/                #   mesh VPN
  vaultwarden/              #   password manager
  cloudflare-tunnel/        #   tunnel ingress
  siteup/                   #   web app deployment

modules/                    # composable feature modules
  nixos/                    #   NixOS system (base, dev, niri, laptop, ...)
  darwin/                   #   Darwin system (base, homebrew)
  home-manager/             #   user config (tools, shell, desktop, fish, git, ...)
    profiles/               #   HM profile groupings (base, desktop, darwin-desktop)

machines/                   # per-machine configurations
dotpkgs/                    # wrapped tool packages via lassulus/wrappers (btop, kitty, nixvim, ...)
pkgs/                       # custom package derivations (claude-code, vesktop)
cloud/                      # AWS/OpenTofu terranix cloud machine provisoning
vars/ + sops/               # secrets (age-encrypted) managed fully thru clan
```

## Data Flow

```
clan-inventory/
  machines.nix          define machines + tags (e.g. "adeci-net")
  instances/            assign service roles to tags
       |
       v
clan-services/          service modules generate NixOS/Darwin config
  @adeci/roster         per role, per instance
  @adeci/tailscale
  ...
       |
       v
machines/               per-machine configuration.nix + home.nix
  aegis/                imports modules explicitly
  claudia/
  ...
       |
       v
deployed system         clan machines update <machine>
```

Inventory declares _what_ runs _where_. Services define _how_. Machine configs add per-host customization. Clan composes it all into a deployable NixOS (or Darwin) system.

## How It Connects

- `flake.nix` imports `flake-outputs/` -- `clan.nix` builds the full config from inventory + services + machines
- The inventory maps service instances to machines via tags (e.g. all `adeci-net` machines get tailscale)
- Each machine explicitly imports the modules it needs
- See [Clan docs](https://docs.clan.lol) for the full service/inventory model

## Services

| Service                    | Description                                                |
| -------------------------- | ---------------------------------------------------------- |
| `@adeci/roster`            | User management, groups, shells, SSH keys (NixOS + Darwin) |
| `@adeci/tailscale`         | Mesh VPN across all machines                               |
| `@adeci/vaultwarden`       | Self-hosted password manager                               |
| `@adeci/cloudflare-tunnel` | Tunnel ingress for exposed services                        |
| `@adeci/siteup`            | Web app deployment (devblog)                               |

### Roster Service

The roster service (`@adeci/roster`) manages users, groups, SSH keys, shells, and passwords across all machines. It runs on every machine via the `tags.all` computed tag.

**Position hierarchy:** `owner > admin > basic > service`

Positions control sudo access, password generation, home directories, and system user flags. Users have a `defaultPosition` that can be overridden per-machine.

Home-manager is handled separately via per-machine `home.nix` files that import profiles from `modules/home-manager/profiles/`.

## Workflows

**Add a machine:**

1. Create `machines/<name>/configuration.nix` (+ `disko.nix` and `facter.json` for NixOS)
2. Add entry to `clan-inventory/machines.nix` with appropriate tags
3. Add the machine with user assignments in `clan-inventory/instances/roster/machines.nix`
4. `git add` the new files, then `nix build` to verify

**Add a Darwin machine:**

1. Create `machines/<name>/configuration.nix` importing Darwin modules explicitly
2. Set `nixpkgs.hostPlatform` and `system.stateVersion`
3. Add to `clan-inventory/machines.nix` with `machineClass = "darwin"` and empty tags
4. Add roster user assignments in `clan-inventory/instances/roster/machines.nix`
5. `git add` the new files, then `nix build .#darwinConfigurations.<name>.system` to verify

**Add a user:**

1. Add user config to `clan-inventory/instances/roster/users.nix` (uid, description, groups, SSH keys, defaultPosition, defaultShell)
2. Add user to machines in `clan-inventory/instances/roster/machines.nix`

**Add an HM profile:**

1. Create `modules/home-manager/profiles/<name>.nix` importing the HM modules you want
2. Import it in the relevant `machines/<name>/home.nix`
3. `git add` the new file before building

**Add a service:**

1. Create service module in `clan-services/<name>/`
2. Create instance config in `clan-inventory/instances/<name>.nix`
3. Assign roles to machine tags

**Deploy:**

```bash
nix build .#nixosConfigurations.<machine>.config.system.build.toplevel  # verify locally
clan machines update <machine>                                          # deploy
```

## Secrets

Secrets are never stored in plaintext in the repository. Two mechanisms are used:

- **Clan vars** (`vars/`) -- secrets prompted once during first deployment, encrypted with age, and persisted. Managed by `clan.core.vars.generators` in service modules. Ideal for service-specific secrets like API keys and passwords.
- **Sops** (`sops/`) -- age-encrypted secret files per machine, user, or service. Decrypted at activation time on the target machine.

All `.age` files are excluded from formatting and linting.

## Standalone Home-Manager

For non-NixOS, non-Darwin machines (e.g. a plain Linux box or WSL), a standalone home-manager configuration is available:

```bash
home-manager switch --flake .#alex-x86_64-linux    # Linux
home-manager switch --flake .#alex-aarch64-darwin   # macOS
```

This provides base tools, shell tools, dev tools, fish, and git -- without requiring NixOS or nix-darwin.

For Clan-managed machines, home-manager is configured via per-machine `home.nix` files instead. The standalone config exists for machines outside the Clan fleet.

## Commands

```bash
nix develop                    # dev shell (clan-cli, opentofu)
nix fmt                        # format everything
clan machines list             # list machines
clan machines update <machine> # deploy
nix build .#<package>          # build a dotpkg (btop, kitty, etc.)
tofu -chdir=cloud plan         # plan cloud changes
tofu -chdir=cloud apply        # apply cloud changes
```

## Links

- [NixOS](https://nixos.org) -- the OS
- [Clan docs](https://docs.clan.lol) -- service model, inventory, vars
- [home-manager](https://github.com/nix-community/home-manager) -- user environment management
