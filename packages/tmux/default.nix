{
  config,
  wlib,
  pkgs,
  ...
}:
let
  fingers = "${pkgs.tmuxPlugins.fingers}/share/tmux-plugins/tmux-fingers/tmux-fingers.tmux";
in
{
  imports = [
    wlib.modules.default
    ../thaw/wrapper.nix
  ];

  package = pkgs.tmux;
  thaw.files."tmux.conf" = ./tmux.conf;
  thaw.reload = ''tmux has-session 2>/dev/null && tmux source-file "$THAW_DIR/tmux.conf"'';

  flags."-f" = "${pkgs.writeText "tmux.conf" ''
    source-file "''$${config.thaw.var}/tmux.conf"
    run-shell ${fingers}
  ''}";
}
