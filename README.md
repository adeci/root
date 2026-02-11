# adeci

Personal infrastructure managed with [Clan](https://clan.lol) (NixOS + Nix flakes).

9 machines, declarative everything, one repo.

## Quick Start

```bash
nix develop          # or: direnv allow
clan machines list   # see what's here
nix fmt              # format everything
```

## Layout

```
flake.nix          # hub: clan, packages, home-manager
dotpkgs/           # wrapped tool packages (btop, kitty, niri, etc.)
clan-services/     # service modules (@adeci/roster, tailscale, etc.)
nix-modules/       # shared NixOS modules (all.nix, dev.nix, niri.nix, ...)
home-manager/      # home-manager configs (fish, git)
inventory/         # what runs where (tag-based)
machines/          # per-machine configs
cloud/             # AWS/OpenTofu for cloud machine provisioning
vars/ + sops/      # secrets (age-encrypted) managed thru clan automatically
```

## Deploy

```bash
# build locally first
nix build .#nixosConfigurations.<machine>.config.system.build.toplevel

# deploy
clan machines update <machine>
```

## Packages

Dotpkgs are wrapped tools with baked-in configs. Available as flake packages:

```bash
nix build .#btop
nix build .#kitty
# etc.
```
