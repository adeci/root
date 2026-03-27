{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      customPkgs = import ../../packages { inherit pkgs inputs; };
    in
    {
      packages = lib.filterAttrs (
        _: pkg:
        let
          eval = builtins.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform pkg);
        in
        eval.success && eval.value
      ) customPkgs;
    };
}
