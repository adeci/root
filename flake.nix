{
  description = "onix computer clan";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
    clan-core.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    adeci-nixvim.url = "github:adeci/nixvim-config";
    adeci-nixvim.inputs.nixpkgs.follows = "nixpkgs";

    adeci-wrappers.url = "github:adeci/wrappers?ref=adeci-wrappers";
    adeci-wrappers.inputs.nixpkgs.follows = "nixpkgs";

    adeci-dotpkgs.url = "path:///home/alex/git/dotpkgs";
    adeci-dotpkgs.inputs.nixpkgs.follows = "nixpkgs";

    grub2-themes.url = "github:vinceliuice/grub2-themes";
    grub2-themes.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    inputs@{
      self,
      clan-core,
      nixpkgs,
      ...
    }:
    let
      clan = clan-core.lib.clan {
        inherit self;
        meta.name = "ONIX";
        meta.tld = "onix";
        inventory = import ./inventory {
          lib = nixpkgs.lib;
          inherit inputs;
        };
        modules = import ./services { inherit nixpkgs; };
        specialArgs = { inherit inputs; };
      };
    in
    clan-core.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      imports = [
        ./formatter.nix
        ./devshell.nix
      ];

      flake = {
        inherit (clan.config) nixosConfigurations nixosModules clanInternals;
        clan = clan.config;
        clanModules = import ./services { inherit nixpkgs; };
      };
    };
}
