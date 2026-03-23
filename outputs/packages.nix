{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      wrappedPkgs = import ../packages/wrapped { inherit pkgs inputs; };
      customPkgs = import ../packages { inherit pkgs inputs; };
      allPkgs = builtins.mapAttrs (_: v: v.wrapper or v) wrappedPkgs // customPkgs;
    in
    {
      packages = lib.filterAttrs (
        _: pkg:
        let
          eval = builtins.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform pkg);
        in
        eval.success && eval.value
      ) allPkgs;
    };
}
