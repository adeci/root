{ pkgs, nixvim, ... }:
{
  nixvim = nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system}.makeNixvimWithModule {
    inherit pkgs;
    module = ./config;
  };
}
