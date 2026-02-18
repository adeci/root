{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      dotpkgs = import ../dotpkgs { inherit pkgs inputs; };
      customPkgs = import ../pkgs { inherit pkgs inputs; };
    in
    {
      packages = builtins.mapAttrs (_: v: v.wrapper or v) dotpkgs // customPkgs;
    };
}
