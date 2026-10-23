{
  lib,
  pkgs,
  self,
  ...
}:
let
  shell = self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-shell;
in
{
  environment.systemPackages = [ shell ];

  systemd.user.services.noctalia-shell = {
    description = "Noctalia desktop shell";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    requisite = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    startLimitIntervalSec = 30;
    startLimitBurst = 5;
    # The shell runs helpers through `sh -c`; give it the session's PATH.
    path = [
      "/run/wrappers"
      "/etc/profiles/per-user/%u"
      "/run/current-system/sw"
    ];
    serviceConfig = {
      ExecStart = lib.getExe shell;
      Restart = "always";
      RestartSec = 1;
      Slice = "app-graphical.slice";
      # Unlocking must not touch the keyring; `login` would create it from the user password.
      Environment = "NOCTALIA_PAM_SERVICE=noctalia-lock";
    };
  };

  security.pam.services.noctalia-lock = { };
}
