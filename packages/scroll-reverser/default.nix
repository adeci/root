# The release zip carries macOS AppleDouble metadata (._IntroShot.png). Info-ZIP
# unzip extracts it as a regular file the code signature's seal doesn't list,
# so Gatekeeper reports the app as damaged.
{ pkgs, ... }:
pkgs.scroll-reverser.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    find "$out" -name '._*' -delete
  '';
})
