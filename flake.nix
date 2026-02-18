{
  description = "adeci's root flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
    clan-core.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    wrappers.url = "github:lassulus/wrappers";
    wrappers.inputs.nixpkgs.follows = "nixpkgs";

    noctalia-shell.url = "github:noctalia-dev/noctalia-shell";
    noctalia-shell.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    grub2-themes.url = "github:vinceliuice/grub2-themes";
    grub2-themes.inputs.nixpkgs.follows = "nixpkgs";

    # temp niri fork for per monitor window rules
    # https://github.com/niri-wm/niri/pull/3474
    niri.url = "github:adeci/niri?ref=window-rule-on-output";
    niri.inputs.nixpkgs.follows = "nixpkgs";

    # Sites
    devblog.url = "github:adeci/devblog";
    devblog.inputs.nixpkgs.follows = "nixpkgs";

    trader-rs.url = "git+ssh://git@github.com/adeci/trader-rs";
    trader-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ clan-core, ... }:
    clan-core.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      imports = [
        ./flake-outputs/clan.nix
        ./flake-outputs/dotpkgs.nix # wrappers
        ./flake-outputs/home-configurations.nix
        ./flake-outputs/formatter.nix
        ./flake-outputs/devshell.nix
        ./clan-services/roster/flake-module.nix
      ];
    };
}
