{ pkgs, ... }:
{
  services.udev.packages = [ pkgs.yubikey-personalization ];

  environment.systemPackages = with pkgs; [
    yubikey-manager
    yubikey-personalization
    libfido2
  ];

  # Desktop notification when YubiKey is waiting for touch
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
}
