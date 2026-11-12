# Built on demand, never as flake checks.
{ lib, self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        leviathan-microvms-test = import ../machines/leviathan/tests/microvms.nix { inherit pkgs self; };
        sequoia-paperless-test = import ../machines/sequoia/tests/paperless.nix { inherit pkgs self; };
      };
    };
}
