{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          inputs.clan-core.packages.${system}.clan-cli
          pkgs.opentofu
        ];
      };
    };
}
