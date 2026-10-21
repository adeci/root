# Dictation with Handy: hold Super+Space to talk, tap to keep recording.
# keyd turns the hotkey into a momentary layer; handy-trigger (root, since
# keyd's socket is root-only) turns its edges into SIGUSR2 for the user's
# handy.service.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
  inherit (packages) handy;
in
{
  imports = [ ./keyd.nix ];

  config = lib.mkIf (packages ? handy) {
    environment.systemPackages = [ handy ];

    # The trigger finds Handy through this unit's cgroup, so Handy started any
    # other way does not react to the hotkey.
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

    systemd.services.handy-trigger = {
      description = "Handy hold-to-talk trigger (keyd layer events)";
      documentation = [
        "https://handy.computer/"
        "https://github.com/rvaiya/keyd"
      ];
      after = [ "keyd.service" ];
      wants = [ "keyd.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.services.keyd.package ]; # for `keyd listen`
      serviceConfig = {
        Type = "simple";
        # 300 ms matches Handy's own hold threshold.
        ExecStart = "${lib.getExe handy.trigger} --layer handy_ptt --threshold-ms 300";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    # Super+Space is unbound in niri, and keyd consumes it before anything else
    # sees it (Ctrl+Space is the tmux prefix).
    services.keyd.keyboards.default.extraConfig = lib.mkAfter ''
      [meta]
      space = layer(handy_ptt)

      [handy_ptt]
    '';

    assertions = [
      {
        assertion = config.services.keyd.enable;
        message = "modules/nixos/handy.nix: the hold-to-talk trigger requires services.keyd (modules/nixos/keyd.nix) to be enabled on this machine.";
      }
    ];
  };
}
