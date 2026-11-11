{
  # Autologin on every greetd start, including after logout.
  nixos =
    { config, self, ... }:
    {
      imports = [
        self.modules.nixos.niri
        self.modules.nixos.primary-user
      ];

      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "niri-session";
          user = config.system.primaryUser;
        };
      };
    };
}
