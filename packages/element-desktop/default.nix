# Electron's safeStorage auto-detection doesn't work on tiling WMs (niri, sway, etc.).
{ pkgs, ... }:
pkgs.element-desktop.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];

  postInstall = (oldAttrs.postInstall or "") + ''
    wrapProgram $out/bin/element-desktop \
      --add-flags "--password-store=gnome-libsecret"
  '';
  meta = oldAttrs.meta // {
    platforms = [ "x86_64-linux" ];
  };
})
