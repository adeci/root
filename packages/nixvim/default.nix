{
  pkgs,
  inputs,
  ...
}:
inputs.nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system}.makeNixvimWithModule {
  inherit pkgs;
  module = ./config;
}
