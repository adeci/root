{
  # launchd starts the app since macOS grants Accessibility to the process launchd spawns; the config's store path in the agent restarts it on change.
  darwin =
    {
      config,
      pkgs,
      self,
      ...
    }:
    let
      kitty = "${config.wrappers.kitty.wrapper}/bin/kitty";

      kitty-home = pkgs.writeShellScript "kitty-home" ''exec ${kitty} -d "$HOME"'';

      kitty-here = pkgs.writeShellScript "kitty-here" ''
        APP_PID=$(osascript -e 'tell application "System Events" to unix id of first process whose frontmost is true' 2>/dev/null)
        if [ -n "$APP_PID" ]; then
          SHELL_PID=$(ps -eo pid=,ppid=,comm= | awk -v ppid="$APP_PID" '$2==ppid && /fish$|bash$|zsh$/ {print $1; exit}')
          if [ -n "$SHELL_PID" ]; then
            CWD=$(lsof -a -p "$SHELL_PID" -d cwd -Fn 2>/dev/null | awk '/^n\//{ print substr($0,2)}')
            if [ -n "$CWD" ] && [ -d "$CWD" ]; then
              exec ${kitty} -d "$CWD"
            fi
          fi
        fi
        exec ${kitty}
      '';

      # Closing a window lets macOS focus the app's next one, possibly on another workspace; come back to where the close started.
      close-here = pkgs.writeShellScript "close-here" ''
        aerospace=${pkgs.aerospace}/bin/aerospace
        workspace=$($aerospace list-workspaces --focused)
        $aerospace close --quit-if-last-window
        sleep 0.1
        $aerospace workspace "$workspace"
      '';

      aerospaceConfig = pkgs.writeText "aerospace.toml" (
        builtins.replaceStrings
          [ "@KITTY_HOME@" "@KITTY_HERE@" "@CLOSE_HERE@" ]
          [ (toString kitty-home) (toString kitty-here) (toString close-here) ]
          (builtins.readFile ./config.toml)
      );

    in
    {
      imports = [
        self.modules.darwin.wrappers
        self.modules.darwin.mac-setup
        self.modules.darwin.code-signing
      ];

      codeSigning.binaries.borders = {
        source = "${self.packages.${pkgs.stdenv.hostPlatform.system}.jankyborders}/bin/borders";
        identifier = "git.felix.borders";
      };

      macSetup.steps = [
        {
          name = "AeroSpace and borders";
          url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
          instructions = "Turn on AeroSpace and borders.";
          grants = [
            {
              service = "kTCCServiceAccessibility";
              client = "bobko.aerospace";
            }
            {
              service = "kTCCServiceAccessibility";
              client = config.codeSigning.binaries.borders.path;
            }
          ];
          restart = [
            "gui/org.nixos.aerospace"
            "gui/org.nixos.jankyborders"
          ];
        }
      ];

      wrappers.kitty.enable = true;
      fonts.packages = [ pkgs.nerd-fonts.caskaydia-mono ];

      environment.systemPackages = [ pkgs.aerospace ];

      launchd.user.agents.aerospace.serviceConfig = {
        ProgramArguments = [
          "/Applications/Nix Apps/AeroSpace.app/Contents/MacOS/AeroSpace"
          "--config-path"
          "${aerospaceConfig}"
        ];
        RunAtLoad = true;
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        LimitLoadToSessionType = "Aqua";
        ProcessType = "Interactive";
      };

      services.jankyborders = {
        enable = true;
        inherit (config.codeSigning.binaries.borders) package;
        active_color = "0xff00C0A3";
        inactive_color = "0xff292e42";
        width = 2.0;
        hidpi = true;
        style = "round";
        # Below, the window's own drop shadow darkens the border's bottom and right edges.
        order = "above";
      };
    };
}
