# root

NixOS and Darwin machines managed with [Clan](https://docs.clan.lol).

8 machines (7 NixOS, 1 Darwin).

## Layout

```
flake.nix
outputs/                    flake-parts output modules

inventory/
  machines.nix              machine declarations + tags
  instances/                service role assignments

modules/
  clan/                     custom clan service definitions (@adeci/*)
  nixos/                    shared NixOS modules
  darwin/                   shared Darwin modules
  home-manager/             home-manager modules
    profiles/               grouped sets of HM modules

machines/<name>/            per-machine config
  configuration.nix         system config (explicit module imports)
  home.nix                  home-manager config (profile imports)
  modules/                  machine-specific modules (if any)

packages/                   custom packages
  wrapped/                  wrapped tools (btop, kitty, nixvim, etc.)

cloud/                      AWS/OpenTofu provisioning
vars/ + sops/               age-encrypted secrets (don't touch)
```

## Quick Start

```bash
nix develop                                    # dev shell
nix fmt                                        # format everything
clan machines list                             # list machines
nix eval .#nixosConfigurations.<m>.config.system.build.toplevel.drvPath  # check eval
clan machines update <machine>                 # deploy
```
