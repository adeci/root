{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      dotpkgs = import ../dotpkgs { inherit pkgs inputs; };
      customPkgs = import ../pkgs { inherit pkgs inputs; };
      allPkgs = builtins.mapAttrs (_: v: v.wrapper or v) dotpkgs // customPkgs;
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
