{ config, pkgs, ... }:
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd}/bin/agreety --cmd niri-session";
      user = config.adeci.primaryUser;
    };
    settings.initial_session = {
      command = "niri-session";
      user = config.adeci.primaryUser;
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;
}
