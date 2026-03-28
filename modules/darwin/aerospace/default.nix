# Aerospace — tiling window manager for macOS
# Generates aerospace.toml with helper scripts and reloads on activation.
{
  lib,
  pkgs,
  config,
  ...
}:
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

  inherit (config.system) primaryUser;
in
{
  homebrew = {
    taps = [
      "FelixKratz/formulae"
      "nikitabobko/tap"
    ];
    brews = [ "FelixKratz/formulae/borders" ];
    casks = [ "nikitabobko/tap/aerospace" ];
  };
  system.activationScripts.postActivation.text = # bash
    lib.mkAfter ''
        AEROSPACE_DIR="/Users/${primaryUser}/.config/aerospace"
      mkdir -p "$AEROSPACE_DIR"
      cp ${aerospaceConfig} "$AEROSPACE_DIR/aerospace.toml"
      /usr/bin/pgrep -x AeroSpace && /opt/homebrew/bin/aerospace reload-config || true
    '';
}
