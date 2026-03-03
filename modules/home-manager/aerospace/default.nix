{
  lib,
  pkgs,
  ...
}:
let
  ghostty-home = pkgs.writeShellScript "ghostty-home" ''exec ghostty --working-directory="$HOME"'';
  ghostty-here = pkgs.writeShellScript "ghostty-here" (builtins.readFile ./ghostty-here.sh);
in
{
  home.file.".config/aerospace/aerospace.toml".text =
    builtins.replaceStrings
      [ "@GHOSTTY_HOME@" "@GHOSTTY_HERE@" ]
      [ (toString ghostty-home) (toString ghostty-here) ]
      (builtins.readFile ./config.toml);

  home.activation.reloadAerospace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.procps}/bin/pgrep -x AeroSpace && /opt/homebrew/bin/aerospace reload-config || true
  '';
}
