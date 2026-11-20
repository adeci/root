{ scroll-reverser }:
scroll-reverser.overrideAttrs (old: {
  # AppleDouble files (._*) sit outside the signature, so Gatekeeper calls the app damaged.
  postInstall = (old.postInstall or "") + ''
    find "$out" -name '._*' -delete
  '';
})
