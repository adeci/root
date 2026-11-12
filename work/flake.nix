{
  inputs = {
    root.url = "path:..";
    nixpkgs.follows = "root/nixpkgs";
    nix-darwin.follows = "root/nix-darwin";
    clan-core.follows = "root/clan-core";
    flake-parts.follows = "root/flake-parts";

    shopify-framework = {
      url = "git+ssh://git@github.com/shopify-playground/shopify-framework?ref=surma/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos-hardware#1912 plus kernel 7.2 fixes; drop once merged.
    nixos-hardware-xps14.url = "github:adeci/nixos-hardware/xps14-7.2-fixes";
    nixos-hardware-xps14.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    let
      stale = import ./root-lock.nix inputs.root;
    in
    if stale != [ ] then
      throw ''
        work/flake.lock is behind root's flake.lock:
          ${builtins.concatStringsSep "\n  " stale}
        Run `nix flake update root` in work/ to re-sync.
      ''
    else
      inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];
        imports = [
          inputs.clan-core.flakeModules.default
          ./flake/clan.nix
          ./flake/modules.nix
        ];

        perSystem =
          { system, ... }:
          {
            formatter = inputs.root.formatter.${system};
            devShells = inputs.root.devShells.${system};
            checks = inputs.root.lib.mkMachineChecks inputs.self system;
          };
      };
}
