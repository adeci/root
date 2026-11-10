{
  nixos =
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
      imports = [ self.modules.nixos.keyd ];

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

        # A system service because keyd's socket is root-only.
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
            message = "handy: the hold-to-talk trigger requires services.keyd (the keyd feature) to be enabled on this machine.";
          }
        ];
      };
    };

  # launchd starts the signed bundle itself, because macOS checks privacy
  # permissions against the process launchd spawned; through the shell wrapper
  # that was bash, not Handy.app. So the settings merge and model link run at
  # activation.
  darwin =
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

      # Handy.app opened by hand runs a binary other than the agent's. Wait for
      # the old one to exit: a second instance just forwards to it and quits.
      system.activationScripts.postActivation.text = # bash
        lib.mkAfter ''
          uid=$(/usr/bin/id -u -- ${user})
          home=$(/usr/bin/dscl . -read /Users/${user} NFSHomeDirectory | /usr/bin/awk '{print $2}')
          data="$home/Library/Application Support/com.pais.handy"
          state() { /sbin/md5 -q "$data/settings_store.json" 2>/dev/null; /bin/ls -l "$data/models" 2>/dev/null; }
          before=$(state || true)
          launchctl asuser "$uid" sudo --user=${user} -- \
            ${lib.getExe handy.setup} ${handy.declaredSettingsFile} ${handy.declaredModels} || true
          after=$(state || true)
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
    };
}
