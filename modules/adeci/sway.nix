{
  pkgs,
  inputs,
  ...
}:
let
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = [
    dotpkgs.sway
    dotpkgs.fuzzel
    dotpkgs.kitty
    dotpkgs.waybar

    pkgs.swayosd # TODO: wrap
    pkgs.swaylock # TODO: wrap
    pkgs.swayidle # TODO: wrap

    pkgs.swaybg
    pkgs.swaycwd

    pkgs.libnotify
    dotpkgs.mako

    pkgs.brightnessctl
    pkgs.playerctl

    pkgs.wl-clipboard
    pkgs.wl-clip-persist

    pkgs.grim
    pkgs.slurp

    pkgs.nerd-fonts.caskaydia-mono

    pkgs.pulseaudio
    pkgs.pavucontrol
    pkgs.jq
    pkgs.xdg-utils
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  security.pam.services.swaylock = { };

  security.polkit.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.xwayland.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [
      "wlr"
      "gtk"
    ];
  };
}
