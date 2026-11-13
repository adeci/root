{ scroll-reverser }:
scroll-reverser.overrideAttrs (old: {
  # unzip leaves the zip's AppleDouble files (._*) outside the code signature, so Gatekeeper calls the app damaged.
  postInstall = (old.postInstall or "") + ''
    find "$out" -name '._*' -delete
  '';
})
