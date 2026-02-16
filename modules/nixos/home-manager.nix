{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.adeci.home-manager;
  dotpkgs = import ../../dotpkgs { inherit pkgs inputs; };
in
{
  options.adeci.home-manager.enable = lib.mkEnableOption "home-manager for user alex";
  imports = [ inputs.home-manager.nixosModules.home-manager ];
  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs dotpkgs; };
      sharedModules = [
        inputs.noctalia-shell.homeModules.default
        ../../modules/home-manager
      ];
    };
  };
}
