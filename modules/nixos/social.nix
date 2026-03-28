# Social/communication apps.
# Electron's safeStorage auto-detection doesn't work on tiling WMs (niri, sway, etc.)
# so we force gnome-libsecret as the password store backend.
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.element-desktop.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        wrapProgram $out/bin/element-desktop \
          --add-flags "--password-store=gnome-libsecret"
      '';
    }))
    (pkgs.signal-desktop.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        wrapProgram $out/bin/signal-desktop \
          --add-flags "--password-store=gnome-libsecret"
      '';
    }))
    (pkgs.vesktop.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.imagemagick ];
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
}
