{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ./desktop-base.nix ];

  options.adeci.niri.user = lib.mkOption {
    type = lib.types.str;
    default = config.adeci.primaryUser;
    description = "User for greetd auto-login";
  };

  config = {
    nixpkgs.overlays = [ inputs.niri.overlays.default ];
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
        inherit (config.adeci.niri) user;
      };
      settings.initial_session = {
        command = "niri-session";
        inherit (config.adeci.niri) user;
      };
    };
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
