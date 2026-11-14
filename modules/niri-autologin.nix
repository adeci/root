{
  nixos =
    { config, self, ... }:
    let
      niri = {
        command = "niri-session";
        user = config.system.primaryUser;
      };
    in
    {
      imports = [
        self.modules.nixos.niri
        self.modules.nixos.primary-user
      ];

      services.greetd = {
        enable = true;
        # logind treats a default session as a greeter, which polkit's agents can't register for: boot uses initial_session, and default_session logs in again after a logout.
        settings.initial_session = niri;
        settings.default_session = niri;
      };
    };
}
