# Local voice dictation using Handy.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  user = lib.escapeShellArg config.system.primaryUser;
  handy = self.packages.${pkgs.stdenv.hostPlatform.system}.handy;
  handyApp = "${handy}/Applications/Handy.app";
in
{
  environment.systemPackages = [ handy ];

  launchd.user.agents.handy.serviceConfig = {
    Label = "org.nixos.handy";
    ProgramArguments = [
      "${handyApp}/Contents/MacOS/handy"
      "--start-hidden"
    ];
    RunAtLoad = true;
    KeepAlive = {
      Crashed = true;
      SuccessfulExit = false;
    };
    LimitLoadToSessionType = "Aqua";
    ProcessType = "Interactive";
  };

  system.activationScripts.postActivation.text = # bash
    lib.mkAfter ''
      # Start Handy after first install; launchd handles future logins.
      if ! /usr/bin/pgrep -qx handy; then
        launchctl asuser "$(/usr/bin/id -u -- ${user})" \
          sudo --user=${user} -- /usr/bin/open -gj ${lib.escapeShellArg handyApp} --args --start-hidden || true
      fi
    '';
}
