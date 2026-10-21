# Dictation with Handy: hold right ⌘ (Handy's own hotkey).
#
# launchd starts the signed bundle itself, because macOS checks privacy
# permissions against the process launchd spawned; through the shell wrapper
# that was bash, not Handy.app. So the settings merge runs at activation.
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
  handyExe = "${handy.unwrapped}/Applications/Handy.app/Contents/MacOS/handy";
in
{
  environment.systemPackages = [ handy ];

  launchd.user.agents.handy.serviceConfig = {
    Label = "org.nixos.handy";
    ProgramArguments = [
      handyExe
      "--start-hidden"
    ];
    EnvironmentVariables.HANDY_DISABLE_UPDATER = "1";
    RunAtLoad = true;
    KeepAlive = {
      Crashed = true;
      SuccessfulExit = false;
    };
    LimitLoadToSessionType = "Aqua";
    ProcessType = "Interactive";
  };

  # Restart Handy only when the merge changed the store or the running binary
  # isn't the agent's current one (e.g. Handy.app opened by hand). Wait for the
  # old one to exit: a second instance just forwards to it and quits.
  system.activationScripts.postActivation.text = # bash
    lib.mkAfter ''
      uid=$(/usr/bin/id -u -- ${user})
      home=$(/usr/bin/dscl . -read /Users/${user} NFSHomeDirectory | /usr/bin/awk '{print $2}')
      store="$home/Library/Application Support/com.pais.handy/settings_store.json"
      before=$(/sbin/md5 -q "$store" 2>/dev/null || true)
      launchctl asuser "$uid" sudo --user=${user} -- \
        ${lib.getExe handy.mergeSettings} ${handy.declaredSettingsFile} || true
      after=$(/sbin/md5 -q "$store" 2>/dev/null || true)
      running=$(/bin/ps -o comm= -p "$(/usr/bin/pgrep -x -u "$uid" handy | /usr/bin/head -n 1)" 2>/dev/null || true)
      if [ "$before" != "$after" ] || [ "$running" != ${lib.escapeShellArg handyExe} ]; then
        /usr/bin/pkill -x -u "$uid" handy || true
        for _ in $(seq 50); do
          /usr/bin/pgrep -qx -u "$uid" handy || break
          sleep 0.1
        done
        launchctl kickstart -k "gui/$uid/org.nixos.handy" || true
      fi
    '';
}
