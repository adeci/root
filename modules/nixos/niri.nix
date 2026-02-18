{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.adeci.niri;
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.adeci.niri = {
    enable = lib.mkEnableOption "Niri compositor";
    user = lib.mkOption {
      type = lib.types.str;
      default = config.adeci.primaryUser;
      description = "User for greetd auto-login";
    };
  };
  config = lib.mkIf cfg.enable {
    adeci.desktop-base.enable = lib.mkDefault true;
    environment.systemPackages = [
      packages.kitty
      pkgs.nautilus
      pkgs.xwayland-satellite
    ];
    programs.niri.enable = true;

    # Auto-login into niri via greetd
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.greetd}/bin/agreety --cmd niri-session";
        user = cfg.user;
      };
      settings.initial_session = {
        command = "niri-session";
        user = cfg.user;
      };
    };
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
