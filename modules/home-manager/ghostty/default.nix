{
  lib,
  pkgs,
  ...
}:
{
  home.packages = [ (lib.hiPrio pkgs.ghostty) ];

  xdg.configFile."ghostty/config".text = ''
    # Font
    font-family = CaskaydiaCove Nerd Font Mono
    font-size = ${if pkgs.stdenv.isDarwin then "14" else "10"}

    # Theme
    theme = Tokyo Night
    background = 000000

    # Cursor
    cursor-style = block
    cursor-style-blink = true
    custom-shader = cursor-trail.glsl
    custom-shader-animation = always

    # Shell
    command = ${pkgs.fish}/bin/fish --login

    # Behavior
    copy-on-select = clipboard
    confirm-close-surface = false
    window-decoration = false
    clipboard-read = allow
    clipboard-write = allow
    shell-integration = fish
  '';

  xdg.configFile."ghostty/cursor-trail.glsl".source = ./cursor-trail.glsl;
}
