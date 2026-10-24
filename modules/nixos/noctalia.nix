{
  lib,
  pkgs,
  self,
  ...
}:
{
  programs.noctalia = {
    enable = true;
    package = self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia;
    systemd.enable = true;
  };

  systemd.user.services.noctalia = {
    requisite = [ "graphical-session.target" ];
    startLimitIntervalSec = 30;
    startLimitBurst = 5;
    # The shell runs helpers through `sh -c`; give it the session's PATH.
    path = [
      "/run/wrappers"
      "/etc/profiles/per-user/%u"
      "/run/current-system/sw"
    ];
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = 1;
      Slice = "app-graphical.slice";
      # Unlocking must not touch the keyring; `login` would create it from the user password.
      Environment = "NOCTALIA_PAM_SERVICE=noctalia-lock";
    };
  };

  security.pam.services.noctalia-lock = { };
}
