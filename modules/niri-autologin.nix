{
  nixos =
    { config, self, ... }:
    {
      imports = [
        self.modules.nixos.niri
        self.modules.nixos.primary-user
      ];

      services.greetd = {
        enable = true;
        # The default session, not initial_session: it logs in again after logout too.
        settings.default_session = {
          command = "niri-session";
          user = config.system.primaryUser;
        };
      };
    };
}
