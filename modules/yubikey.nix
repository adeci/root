{
  nixos =
    { pkgs, ... }:
    {
      services.pcscd.enable = true;

      services.udev.packages = [ pkgs.yubikey-personalization ];

      # pcscd's own rule lets in only the session at the screen; SSH and TTY logins need the keys too.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if ((action.id == "org.debian.pcsc-lite.access_pcsc" ||
               action.id == "org.debian.pcsc-lite.access_card") &&
              subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';

      environment.systemPackages = [
        pkgs.yubikey-manager
        pkgs.yubikey-personalization
        pkgs.libfido2
        pkgs.age-plugin-yubikey
      ];

      systemd.user.services.yubikey-touch-detector = {
        description = "YubiKey touch detector";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        requisite = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.yubikey-touch-detector}/bin/yubikey-touch-detector --libnotify";
          Restart = "on-failure";
          RestartSec = 1;
        };
        wantedBy = [ "graphical-session.target" ];
      };
    };
}
