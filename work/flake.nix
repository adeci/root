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
          ./modules/flake-parts/clan.nix
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
