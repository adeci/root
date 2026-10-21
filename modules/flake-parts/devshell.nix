{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          inputs.clan-core.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli
          pkgs.opentofu
        ];
      };
    };
}
