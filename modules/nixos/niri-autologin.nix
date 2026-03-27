{ pkgs, self, ... }:
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd}/bin/agreety --cmd niri-session";
      user = self.users.alex.username;
    };
    settings.initial_session = {
      command = "niri-session";
      user = self.users.alex.username;
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;
}
