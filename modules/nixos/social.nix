# Electron's safeStorage auto-detection doesn't work on tiling WMs (niri, sway, etc.)
# so we force gnome-libsecret as the password store backend.
{
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
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
    packages.vesktop
  ];
}
