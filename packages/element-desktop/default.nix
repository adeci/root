# Electron's safeStorage auto-detection doesn't work on tiling WMs (niri, sway, etc.) so force gnome-libsecret as the password store backend.
{ pkgs, ... }:
pkgs.element-desktop.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];

  postInstall = (oldAttrs.postInstall or "") + ''
    wrapProgram $out/bin/element-desktop \
      --add-flags "--password-store=gnome-libsecret"
  '';
})
