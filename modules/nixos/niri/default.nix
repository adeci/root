# Full desktops bring their own polkit agent; niri doesn't.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
  machineKdl = config.thaw.apps.niri.files."machine.kdl" or null;
in
{
  programs.niri.enable = true;
  programs.niri.package = packages.niri;

  environment.systemPackages = [
    pkgs.xwayland-satellite
    pkgs.wl-clipboard
    pkgs.wl-clip-persist
    pkgs.wl-mirror
    pkgs.playerctl
    pkgs.brightnessctl
  ];

  # Validate the shared config with this machine's file beside it, as niri sees them.
  system.checks = lib.optional (machineKdl != null) (
    pkgs.runCommand "niri-machine-config" { } ''
      cp ${../../../packages/niri/config.kdl} config.kdl
      cp ${machineKdl} machine.kdl
      ${lib.getExe config.programs.niri.package} validate -c config.kdl
      touch $out
    ''
  );

  systemd.user.services.polkit-gnome = {
    description = "Polkit GNOME authentication agent";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    requisite = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
