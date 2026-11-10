{
  wlib,
  pkgs,
  ...
}:
let
  fingers = "${pkgs.tmuxPlugins.fingers}/share/tmux-plugins/tmux-fingers/tmux-fingers.tmux";
in
{
  imports = [ wlib.modules.default ];

  package = pkgs.tmux;

  flags."-f" = "${pkgs.writeText "tmux.conf" ''
    source-file ${./tmux.conf}
    run-shell ${fingers}
  ''}";
}
