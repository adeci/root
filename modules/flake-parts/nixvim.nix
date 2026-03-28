# Nixvim — standalone neovim package with baked-in config.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.nixvim = inputs.nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
        inherit pkgs;
        module = ../nixvim;
      };
    };
}
