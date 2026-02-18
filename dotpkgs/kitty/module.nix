{ pkgs, wrappers, ... }:
{
  kitty = wrappers.wrapperModules.kitty.apply {
      inherit pkgs;
      settings = {
        # Font
        font_family = "CaskaydiaMono Nerd Font";
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";
        font_size = "10.0";
        # Cursor
        cursor_shape = "block";
        cursor_blink_interval = "0.5";
        cursor_stop_blinking_after = 0;
        cursor_trail = 3;
        cursor_trail_decay = "0.1 0.4";
        # Behavior
        enable_audio_bell = "no";
        copy_on_select = "yes";
        confirm_os_window_close = 0;
        hide_window_decorations = "yes";
        filter_notification = "all";
        paste_actions = "no-op";
        clipboard_control = "write-clipboard write-primary read-clipboard read-primary";
        # Tokyo Night colors
        background = "#000000";
        foreground = "#c0caf5";
        selection_background = "#283457";
        selection_foreground = "#c0caf5";
        url_color = "#73daca";
        cursor = "#c0caf5";
        cursor_text_color = "#1a1b26";
        # Tabs
        active_tab_background = "#7aa2f7";
        active_tab_foreground = "#16161e";
        inactive_tab_background = "#292e42";
        inactive_tab_foreground = "#545c7e";
        # Windows
        active_border_color = "#7aa2f7";
        inactive_border_color = "#292e42";
        # Normal colors
        color0 = "#15161e";
        color1 = "#f7768e";
        color2 = "#9ece6a";
        color3 = "#e0af68";
        color4 = "#7aa2f7";
        color5 = "#bb9af7";
        color6 = "#7dcfff";
        color7 = "#a9b1d6";
        # Bright colors
        color8 = "#414868";
        color9 = "#ff899d";
        color10 = "#9fe044";
        color11 = "#faba4a";
        color12 = "#8db0ff";
        color13 = "#c7a9ff";
        color14 = "#a4daff";
        color15 = "#c0caf5";
        # Extended colors
        color16 = "#ff9e64";
        color17 = "#db4b4b";
      };
    };
}
