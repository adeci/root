# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Root is a personal infrastructure configuration using the **Clan** framework (built on NixOS and Nix flakes). It manages 9 machines (7 active NixOS + 1 Darwin; bambrew and marine commented out), services, users, and secrets through declarative, reproducible infrastructure-as-code.

## Common Commands

```bash
# Enter development shell (provides clan-cli and opentofu)
nix develop
# or use direnv (configured in .envrc)
direnv allow

# Format all code
nix fmt

# Build a machine configuration locally (to check for errors)
nix build .#nixosConfigurations.<machine-name>.config.system.build.toplevel

# Build Darwin configuration
nix build .#darwinConfigurations.malum.system

# Deploy a machine
clan machines update <machine-name>

# List machines
clan machines list

# Manage cloud infrastructure (AWS/OpenTofu, from cloud/ directory)
tofu -chdir=cloud plan
tofu -chdir=cloud apply
```

## Architecture

### Flake Structure (`flake.nix`)

The flake uses `flake-parts` and `clan-core.lib.clan` to wire everything together. The clan config is built from three main sources:
- `clan-inventory/` — declares which service instances run on which machines
- `clan-services/` — defines the clan service modules
- `machines/` — per-machine NixOS/Darwin configurations

### Flake Outputs (`flake-outputs/`)

Modular flake output definitions, each imported by `flake.nix`:
- `clan.nix` — clan config wiring (inventory, services, machines)
- `dotpkgs.nix` — wrapped tool packages from `dotpkgs/`
- `home-configurations.nix` — standalone `homeConfigurations.alex`
- `formatter.nix` — treefmt-nix rules
- `devshell.nix` — development shell

Note: `clan-services/roster/flake-module.nix` is also imported directly (for roster eval tests).

### Clan Service Model (`clan-services/`)

Services are namespaced `@adeci/*` and follow the clan service pattern:
- `_class = "clan.service"` marker
- `manifest` with metadata
- One or more `roles` with `perInstance` implementations
- Secrets provisioned via `clan.core.vars.generators`

All services: `@adeci/roster`, `@adeci/tailscale`, `@adeci/vaultwarden`, `@adeci/cloudflare-tunnel`, `@adeci/siteup`

### Dotpkgs (`dotpkgs/`)

Wrapped tool packages (btop, fuzzel, kitty, nixvim, starship). Each tool is a directory with a `module.nix`. The `default.nix` dynamically discovers all subdirectories. Depends on the `wrappers` flake input (from `lassulus/wrappers`).

### Custom Packages (`pkgs/`)

Custom package derivations auto-discovered via `callPackage`:
- `claude-code` — re-exported from nixpkgs-master
- `vesktop` — custom splash override

### Inventory System (`clan-inventory/`)

- `machines.nix` — lists all machines; NixOS machines tagged `"adeci-net"`, malum (Darwin) has empty tags
- `instances/` — service instance definitions that map roles to machines via tags
- `instances/roster/` — user management (SSH keys, groups, shells) applied across all machines

The inventory drives deployment: a service instance declares a role and a machine tag, and all machines with that tag get the service.

### Machine Configs (`machines/<name>/`)

Each machine directory typically contains:
- `configuration.nix` — main config, imports `../../modules/nixos` (or `../../modules/darwin` for malum)
- `disko.nix` — declarative disk partitioning layout (NixOS only)
- `facter.json` — auto-generated hardware facts (NixOS only)
- `home.nix` — home-manager user config (Darwin)

### Modules (`modules/`)

All modules use the `adeci.*` option namespace and are auto-discovered via `default.nix`.

**`modules/nixos/`** — NixOS system modules:
`base`, `dev`, `shell`, `desktop-base`, `niri`, `keyd`, `amd-gpu`, `ssh`, `workstation`, `laptop`, `gaming`, `creative`, `gnome`, `social`, `printing`, `home-manager`, `gpd-pocket-4-audio`

**`modules/darwin/`** — Darwin system modules:
`base`, `homebrew`, `home-manager`

**`modules/home-manager/`** — User-level modules (shared across NixOS and Darwin):
`base-tools`, `shell-tools`, `dev-tools`, `desktop`, `fish`, `git`, `karabiner`, `aerospace`
Directories with a `default.nix` are also auto-discovered (e.g. `karabiner/`, `aerospace/`).

### Secrets (`vars/`, `sops/`)

- `vars/` — clan vars (secrets prompted once during deployment, encrypted with age, persisted)
- `sops/` — age-encrypted secrets per machine/user/service
- Secret files are `.age` encrypted and excluded from formatting

### Cloud Infrastructure (`cloud/`)

AWS resources (EC2 for the `claudia` machine) managed via OpenTofu/Terraform. Config in `infrastructure.nix`, generates `config.tf.json`.

## Code Formatting

Managed by `treefmt-nix` (configured in `flake-outputs/formatter.nix`):
- **nixfmt** + **deadnix** for Nix files
- **prettier** for JS/JSON/YAML/Markdown/CSS
- **shellcheck** for shell scripts

Run `nix fmt` to format everything. Files matching `*.age`, `*.pub`, `*.toml`, `*.desktop` are excluded.

## Nix Gotchas

- New files **must** be `git add`ed before `nix build` can see them (flake git tracking requirement)
- nix-darwin requires `system.primaryUser` for options like `homebrew.enable`, `system.defaults.*`
- Standalone `homeManagerConfiguration` doesn't inherit `nixpkgs.config.allowUnfree` — must use `import nixpkgs { config.allowUnfree = true; }` instead of `nixpkgs.legacyPackages`
- clan-core requires `roles.*.interface` to be JSON-serializable — no `types.package`, `types.deferredModule`, or `types.attrs`

## Key Conventions

- All Nix code follows nixfmt style
- Service modules use the `@adeci/` namespace prefix
- All feature modules use the `adeci.*` option namespace
- Modules are auto-discovered via `default.nix` in each `modules/` subdirectory
- Machine targeting is tag-based; NixOS machines share the `"adeci-net"` tag; `malum` has empty tags (excluded from NixOS-only services)
- Secrets are never stored in plaintext in git — use clan vars generators or sops/age
- The primary user is `alex` (adeci); other users are managed via the roster service
- `git add` new files before `nix build` (flake git tracking)
