# root

Personal infrastructure as code monorepo — NixOS and Darwin machines managed with [Clan](https://clan.lol).

## Quick Start

```bash
nix develop          # or: direnv allow
clan machines list   # see what's here
nix fmt              # format everything
```

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
  instances/                #   service → machine assignments
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

machines/                   # per-machine configurations
dotpkgs/                    # wrapped tool packages (btop, kitty, nixvim, ...)
pkgs/                       # custom package derivations (claude-code, vesktop)
cloud/                      # AWS/OpenTofu terranix cloud machine provisoning
vars/ + sops/               # secrets (age-encrypted) managed fully thru clan
```

## How It Connects

- `flake.nix` imports `flake-outputs/` — `clan.nix` builds the full config from inventory + services + machines
- The inventory maps service instances to machines via tags (e.g. all `adeci-net` machines get tailscale)
- Each machine imports `modules/` and enables features via `adeci.*` options
- See [Clan docs](https://docs.clan.lol) for the full service/inventory model

## Services

| Service                    | Description                                                    |
| -------------------------- | -------------------------------------------------------------- |
| `@adeci/roster`            | User management, groups, shells, home-manager (NixOS + Darwin) |
| `@adeci/tailscale`         | Mesh VPN across all machines                                   |
| `@adeci/vaultwarden`       | Self-hosted password manager                                   |
| `@adeci/cloudflare-tunnel` | Tunnel ingress for exposed services                            |
| `@adeci/siteup`            | Web app deployment (devblog)                                   |

## Workflows

**Add a machine:**

1. Create `machines/<name>/configuration.nix` (+ `disko.nix`, `facter.json` if NixOS)
2. Add entry to `clan-inventory/machines.nix` with tags
3. `git add` the new files, then `nix build` to verify

**Add a user:**

1. Add user config in `clan-inventory/instances/roster/`
2. Roster service generates system users + home-manager on all tagged machines

**Add a service:**

1. Create service module in `clan-services/<name>/`
2. Create instance config in `clan-inventory/instances/<name>.nix`
3. Assign roles to machine tags

**Deploy:**

```bash
nix build .#nixosConfigurations.<machine>.config.system.build.toplevel  # verify locally
clan machines update <machine>                                          # deploy
```

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

- [NixOS](https://nixos.org) — the OS
- [Clan docs](https://docs.clan.lol) — service model, inventory, vars
- [home-manager](https://github.com/nix-community/home-manager) — user environment management
