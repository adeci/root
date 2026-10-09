{
  inputs = {
    root.url = "path:..";
    nixpkgs.follows = "root/nixpkgs";
    nix-darwin.follows = "root/nix-darwin";
    clan-core.follows = "root/clan-core";
    flake-parts.follows = "root/flake-parts";

    # NixOS/nixos-hardware#1912 (Dell XPS 14 DA14260) until it merges; then
    # drop this and use root's nixos-hardware.
    nixos-hardware.url = "github:cooparo/nixos-hardware/dell-xps-14-da14260";

    shopify-framework = {
      url = "git+ssh://git@github.com/shopify-playground/shopify-framework?ref=surma/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      imports = [
        inputs.clan-core.flakeModules.default
        ./modules/flake-parts/clan.nix
        ./modules/flake-parts/users.nix
      ];

      perSystem =
        { lib, system, ... }:
        let
          # Check every work machine built for this system.
          machinesFor = lib.filterAttrs (_name: machine: machine.pkgs.stdenv.hostPlatform.system == system);
        in
        {
          formatter = inputs.root.formatter.${system};
          devShells = inputs.root.devShells.${system};
          checks =
            lib.mapAttrs' (n: machine: lib.nameValuePair "nixos-${n}" machine.config.system.build.toplevel) (
              machinesFor inputs.self.nixosConfigurations
            )
            // lib.mapAttrs' (n: machine: lib.nameValuePair "darwin-${n}" machine.system) (
              machinesFor inputs.self.darwinConfigurations
            );
        };
    };
}
