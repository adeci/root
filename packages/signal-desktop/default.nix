# Electron's safeStorage auto-detection doesn't work on tiling WMs (niri, sway, etc.) so force gnome-libsecret as the password store backend.
{ pkgs, ... }:
pkgs.signal-desktop.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];

  postInstall = (oldAttrs.postInstall or "") + ''
    wrapProgram $out/bin/signal-desktop \
      --add-flags "--password-store=gnome-libsecret"
  '';
})
