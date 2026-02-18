{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.base;
in
{
  options.adeci.base.enable = lib.mkEnableOption "base system configuration";
  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
    nix.settings = {
      http-connections = 64;
      max-substitution-jobs = 64;
      download-buffer-size = 268435456; # 256MB
    };
    environment.systemPackages = [ pkgs.kitty.terminfo ];
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };
}
