{
  config,
  pkgs,
  ...
}:
let
  wallpaperDir = "${config.home.homeDirectory}/wallpapers";
  wallpaperImage = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_nix.png";
    sha256 = "sha256-W5GaKCOiV2S3NuORGrRaoOE2x9X6gUS+wYf7cQkw9CY=";
  };
in
{
  home.file."wallpapers/tokyo-night-nix.png".source = wallpaperImage;
  programs.noctalia-shell = {
    enable = true;
    settings = {
      general = {
        terminal = "kitty";
        clockFormat = "h:mm\\nAP";
      };
      colorSchemes = {
        predefinedScheme = "Tokyo Night";
        darkMode = true;
      };
      appLauncher = {
        terminalCommand = "kitty -e";
        enableClipboardHistory = true;
      };
      bar = {
        barType = "simple";
        position = "top";
        outerCorners = false;
        widgets = {
          left = [
            { id = "Launcher"; }
            {
              id = "Clock";
              formatHorizontal = "h:mm AP";
            }
            { id = "SystemMonitor"; }
            { id = "ActiveWindow"; }
            { id = "MediaMini"; }
          ];
          center = [
            { id = "Workspace"; }
          ];
          right = [
            { id = "Tray"; }
            { id = "NotificationHistory"; }
            { id = "VPN"; }
            { id = "Network"; }
            { id = "Battery"; }
            { id = "Volume"; }
            { id = "Brightness"; }
            { id = "ControlCenter"; }
          ];
        };
      };
      dock = {
        enabled = false;
      };
      wallpaper = {
        enabled = true;
        directory = wallpaperDir;
        skipStartupTransition = true;
      };
      notifications = {
        location = "top_right";
      };
      osd = {
        location = "top_right";
      };
      location = {
        name = "";
        useFahrenheit = true;
        use12hourFormat = true;
      };
      controlCenter = {
        cards = [
          {
            enabled = true;
            id = "profile-card";
          }
          {
            enabled = true;
            id = "shortcuts-card";
          }
          {
            enabled = true;
            id = "audio-card";
          }
          {
            enabled = false;
            id = "weather-card";
          }
          {
            enabled = true;
            id = "media-sysmon-card";
          }
        ];
      };
      desktopWidgets = {
        enabled = false;
      };
      nightLight = {
        enabled = false;
      };
    };
  };
}
