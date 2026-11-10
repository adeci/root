{ self, ... }:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          self.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli
          pkgs.opentofu
        ];
      };
    };
}
