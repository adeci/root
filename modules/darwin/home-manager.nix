{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  cfg = config.adeci.home-manager;
in
{
  options.adeci.home-manager.enable = lib.mkEnableOption "home-manager infrastructure";
  imports = [ inputs.home-manager.darwinModules.home-manager ];
  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs self; };
      sharedModules = [
        inputs.noctalia-shell.homeModules.default
        ../../modules/home-manager
        { targets.darwin.copyApps.enableChecks = false; }
      ];
    };
  };
}
