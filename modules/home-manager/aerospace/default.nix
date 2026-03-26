{
  lib,
  pkgs,
  ...
}:
let
  kitty-home = pkgs.writeShellScript "kitty-home" ''exec kitty -d "$HOME"'';
  kitty-here = pkgs.writeShellScript "kitty-here" (builtins.readFile ./kitty-here.sh);
in
{
  home.file.".config/aerospace/aerospace.toml".text =
    builtins.replaceStrings
      [ "@KITTY_HOME@" "@KITTY_HERE@" ]
      [ (toString kitty-home) (toString kitty-here) ]
      (builtins.readFile ./config.toml);

  home.activation.reloadAerospace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /usr/bin/pgrep -x AeroSpace && /opt/homebrew/bin/aerospace reload-config || true
  '';
}
