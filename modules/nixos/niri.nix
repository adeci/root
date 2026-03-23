{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [ ./desktop-base.nix ];

  nixpkgs.overlays = [ inputs.niri.overlays.default ];
  environment.systemPackages = [
    pkgs.kitty
    pkgs.nautilus
    pkgs.xwayland-satellite
  ];
  programs.niri.enable = true;

  # Auto-login into niri via greetd
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd}/bin/agreety --cmd niri-session";
      user = config.adeci.primaryUser;
    };
    settings.initial_session = {
      command = "niri-session";
      user = config.adeci.primaryUser;
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;
}
