# rbw (unofficial Bitwarden CLI) with lock-on-suspend service.
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.rbw
    pkgs.pinentry-curses
  ];

  systemd.user.services.lock-rbw-on-suspend = {
    description = "Lock rbw before suspend";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.rbw}/bin/rbw lock";
    };
  };
}
