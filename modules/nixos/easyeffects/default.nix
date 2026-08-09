# EasyEffects service and system-wide presets.
{ pkgs, ... }:
let
  presets = pkgs.runCommand "easyeffects-presets" { } ''
    mkdir -p $out/share/easyeffects/input
    cp ${./presets}/*.json $out/share/easyeffects/input/
  '';
in
{
  environment.systemPackages = [
    pkgs.easyeffects
    presets
  ];
  environment.pathsToLink = [ "/share/easyeffects" ];

  systemd.user.services.easyeffects = {
    description = "EasyEffects audio processing";
    partOf = [ "graphical-session.target" ];
    after = [
      "graphical-session.target"
      "pipewire.service"
    ];
    requisite = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.easyeffects}/bin/easyeffects --gapplication-service";
      Restart = "on-failure";
      RestartSec = 3;
    };
    wantedBy = [ "graphical-session.target" ];
  };
}
