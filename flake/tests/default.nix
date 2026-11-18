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
    lib.optionalAttrs (system == "x86_64-linux") {
      checks.sequoia-paperless-test = callPackage ../../machines/sequoia/tests/paperless.nix { };
      checks.sequoia-vaultwarden-restore-test =
        callPackage ../../machines/sequoia/tests/vaultwarden-restore.nix
          { };

      # Not a check: it flakes under load.
      packages.leviathan-microvms-test = callPackage ../../machines/leviathan/tests/microvms.nix { };
    };
}
