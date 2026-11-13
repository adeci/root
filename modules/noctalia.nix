{
  nixos =
    {
      config,
      lib,
      self,
      ...
    }:
    {
      imports = [ self.modules.nixos.wrappers ];

      programs.noctalia = {
        enable = true;
        package = config.wrappers.noctalia.wrapper;
        systemd.enable = true;
      };

      systemd.user.services.noctalia = {
        requisite = [ "graphical-session.target" ];
        startLimitIntervalSec = 30;
        startLimitBurst = 5;
        serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = 1;
          Slice = "app-graphical.slice";
        };
      };
    };
}
