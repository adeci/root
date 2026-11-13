{
  inputs,
  lib,
  self,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      callPackage = pkgs.newScope { inherit self inputs; };
    in
    {
      # VM tests, built on demand and never by `nix flake check`.
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        leviathan-microvms-test = callPackage ../machines/leviathan/tests/microvms.nix { };
        sequoia-paperless-test = callPackage ../machines/sequoia/tests/paperless.nix { };
      };
    };
}
