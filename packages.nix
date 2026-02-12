{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = builtins.mapAttrs (_: v: if v ? wrapper then v.wrapper else v) (
        import ./dotpkgs { inherit pkgs inputs; }
      );
    };
}
