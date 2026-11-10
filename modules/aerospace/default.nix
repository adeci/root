{
  # AeroSpace, the tiling window manager, plus borders around the focused window.
  # launchd starts the app itself (macOS grants Accessibility to the process
  # launchd spawns) with the config straight from the store; a config change
  # changes the agent, so the switch restarts AeroSpace on it.
  darwin =
    { pkgs, ... }:
    let
      kitty-home = pkgs.writeShellScript "kitty-home" ''exec kitty -d "$HOME"'';

      kitty-here = pkgs.writeShellScript "kitty-here" ''
        APP_PID=$(osascript -e 'tell application "System Events" to unix id of first process whose frontmost is true' 2>/dev/null)
        if [ -n "$APP_PID" ]; then
          SHELL_PID=$(ps -eo pid=,ppid=,comm= | awk -v ppid="$APP_PID" '$2==ppid && /fish$|bash$|zsh$/ {print $1; exit}')
          if [ -n "$SHELL_PID" ]; then
            CWD=$(lsof -a -p "$SHELL_PID" -d cwd -Fn 2>/dev/null | awk '/^n\//{ print substr($0,2)}')
            if [ -n "$CWD" ] && [ -d "$CWD" ]; then
              exec kitty -d "$CWD"
            fi
          fi
        fi
        exec kitty
      '';

      aerospaceConfig = pkgs.writeText "aerospace.toml" (
        builtins.replaceStrings
          [ "@KITTY_HOME@" "@KITTY_HERE@" ]
          [ (toString kitty-home) (toString kitty-here) ]
          (builtins.readFile ./config.toml)
      );

    in
    {
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
        active_color = "0xff00C0A3";
        inactive_color = "0xff292e42";
        width = 6.0;
        style = "round";
      };
    };
}
