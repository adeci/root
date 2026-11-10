{
  # Autologin on every greetd start, including after logout.
  nixos =
    { self, ... }:
    {
      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "niri-session";
          user = self.users.alex.username;
        };
      };
    };
}
