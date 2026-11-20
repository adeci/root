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
        # logind counts default_session as a greeter (no polkit agent): use it only after logout.
        settings.initial_session = niri;
        settings.default_session = niri;
      };
    };
}
