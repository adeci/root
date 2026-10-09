{
  inputs = {
    root.url = "path:..";
    nixpkgs.follows = "root/nixpkgs";
    nix-darwin.follows = "root/nix-darwin";
    clan-core.follows = "root/clan-core";
    flake-parts.follows = "root/flake-parts";
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
        { system, ... }:
        {
          formatter = inputs.root.formatter.${system};
          devShells = inputs.root.devShells.${system};
          checks = inputs.nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
            darwin-malum = inputs.self.darwinConfigurations.malum.system;
          };
        };
    };
}
