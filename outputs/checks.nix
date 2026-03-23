{ self, ... }:
{
  perSystem =
    {
      self',
      lib,
      system,
      ...
    }:
    let
      machinesPerSystem = {
        x86_64-linux = [
          "aegis"
          "claudia"
          "kasha"
          "leviathan"
          "modus"
          "praxis"
          "sequoia"
        ];
      };

      nixosMachines = lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
        lib.genAttrs (machinesPerSystem.${system} or [ ]) (
          name: self.nixosConfigurations.${name}.config.system.build.toplevel
        )
      );

      packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;

      devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
    in
    {
      checks = nixosMachines // packages // devShells;
    };
}
