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

  # greetd needs gnome-keyring PAM integration so the keyring daemon
  # starts properly for the graphical session (even with autologin).
  security.pam.services.greetd.enableGnomeKeyring = true;
}
