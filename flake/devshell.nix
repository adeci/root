{
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          self'.packages.clan-cli
          pkgs.opentofu
        ];
      };
    };
}
