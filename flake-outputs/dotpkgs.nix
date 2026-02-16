{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      dotpkgs = import ../dotpkgs { inherit pkgs inputs; };
      customPkgs = import ../pkgs { inherit pkgs inputs; };
    in
    {
      packages = builtins.mapAttrs (_: v: if v ? wrapper then v.wrapper else v) dotpkgs // customPkgs;
    };
}
