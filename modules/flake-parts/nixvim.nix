# Nixvim — standalone neovim package with baked-in config.
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages.nixvim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
        inherit pkgs;
        module = ../nixvim;
      };
    };
}
