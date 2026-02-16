{ config, lib, ... }:
let
  cfg = config.adeci.git;
in
{
  options.adeci.git.enable = lib.mkEnableOption "Git configuration";
  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user.name = "adeci";
        user.email = "alex.decious@gmail.com";
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };
  };
}
