{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.dev-tools;
in
{
  options.adeci.dev-tools.enable = lib.mkEnableOption "development tools (gh, jujutsu, lazygit)";
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      awscli2
      gh
      jujutsu
      nixpkgs-review
      nix-output-monitor
      socat
      lsof
      lazygit
      screen
      tio
      pueue
      dmidecode
    ];
  };
}
