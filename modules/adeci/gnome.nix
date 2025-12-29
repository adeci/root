{ pkgs, ... }:
let

  wallpaper = pkgs.fetchurl {
    name = "osaka-jade-bg-3.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/osaka-jade-bg-3.jpg";
    sha256 = "sha256-FFrfC6Lr1C2rr4nxJwmnMhZ09idmjk4sM/yPihkpFMc=";
  };

in
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  environment.systemPackages = with pkgs; [
    gnome-tweaks
  ];

  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/background" = {
            picture-uri = "file://${wallpaper}";
            picture-uri-dark = "file://${wallpaper}";
            picture-options = "zoom";
          };
        };
      }
    ];
  };

}
