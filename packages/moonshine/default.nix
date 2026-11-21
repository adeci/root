{ inputs, pkgs }:
(inputs.moonshine.overlays.default pkgs pkgs).moonshine.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./pairing-attempts-end.patch
    ./pin-page-result.patch
    ./pin-page-waiting-client.patch
    ./unknown-mac-as-zeros.patch
  ];
  # ferriscope is a vendored crate, so patch cargo's copy of it.
  postPatch = old.postPatch + ''
    patch -d "$cargoDepsCopy"/ferriscope-0.2.0 -p1 < ${./ferriscope-empty-scene-frames.patch}
  '';
  meta = old.meta // {
    platforms = [ "x86_64-linux" ];
  };
})
