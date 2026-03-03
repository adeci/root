{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;

    # Font
    font = {
      name = "CaskaydiaMono Nerd Font Mono";
      size = if pkgs.stdenv.isDarwin then 14.0 else 10.0;
    };

    # Theme (replaces 30+ manual color lines)
    themeFile = "tokyo_night_night";

    settings = {
      # Font variants
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";

      # Cursor
      cursor_shape = "block";
      cursor_blink_interval = "0.5";
      cursor_stop_blinking_after = 0;
      cursor_trail = 3;
      cursor_trail_decay = "0.1 0.4";

      # Shell
      shell = "${pkgs.fish}/bin/fish --login";

      # Behavior
      enable_audio_bell = false;
      copy_on_select = "yes";
      confirm_os_window_close = 0;
      hide_window_decorations = "titlebar-only";
      filter_notification = "all";
      paste_actions = "no-op";
      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";

      # Override theme background to pure black
      background = "#000000";
    };
  };
}
