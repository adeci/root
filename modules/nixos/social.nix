{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.social;
in
{
  options.adeci.social.enable = lib.mkEnableOption "social apps (Element, Signal, Vesktop)";
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (element-desktop.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          wrapProgram $out/bin/element-desktop \
            --add-flags "--password-store=gnome-libsecret"
        '';
      }))
      (signal-desktop.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          wrapProgram $out/bin/signal-desktop \
            --add-flags "--password-store=gnome-libsecret"
        '';
      }))
      (vesktop.overrideAttrs (oldAttrs: {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ imagemagick ];
        postPatch = (oldAttrs.postPatch or "") + ''
          convert -coalesce ${
            pkgs.fetchurl {
              url = "https://raw.githubusercontent.com/adeci/wallpapers/refs/heads/main/nixos.gif";
              hash = "sha256-XGpc+QhVqBUvNxIarc50y8qvPAHwziR8pLI2TyBWXsQ=";
            }
          } static/splash.webp
        '';
      }))
    ];
  };
}
