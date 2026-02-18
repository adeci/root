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
  options.adeci.niri.enable = lib.mkEnableOption "Niri compositor";
  config = lib.mkIf cfg.enable {
    adeci.desktop-base.enable = lib.mkDefault true;
    environment.systemPackages = [
      packages.kitty
      pkgs.nautilus
      pkgs.xwayland-satellite
    ];
    programs.niri.enable = true;

    # Auto-login alex into niri via greetd
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.greetd}/bin/agreety --cmd niri-session";
        user = "alex";
      };
      settings.initial_session = {
        command = "niri-session";
        user = "alex";
      };
    };
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
