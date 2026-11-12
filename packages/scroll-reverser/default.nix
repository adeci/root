# unzip extracts the release zip's AppleDouble files (._IntroShot.png) as regular files outside the code signature's seal, so Gatekeeper calls the app damaged.
{ pkgs, ... }:
pkgs.scroll-reverser.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    find "$out" -name '._*' -delete
  '';
})
