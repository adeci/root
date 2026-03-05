{ pkgs, lib, ... }:
{
  home.packages = [ pkgs.rbw ];

  systemd.user.services = lib.mkIf pkgs.stdenv.isLinux {
    lock-rbw-on-suspend = {
      Unit = {
        Description = "Lock rbw before suspend";
        Before = [ "sleep.target" ];
      };
      Install.WantedBy = [ "sleep.target" ];
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.rbw}/bin/rbw lock";
      };
    };
  };
}
