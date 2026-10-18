# Local voice dictation using Handy.
{
  lib,
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
  inherit (packages) handy;
in
lib.mkIf (packages ? handy) {
  environment.systemPackages = [ handy ];

  systemd.user.services.handy = {
    description = "Handy speech-to-text";
    documentation = [ "https://handy.computer/" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe handy} --start-hidden";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
