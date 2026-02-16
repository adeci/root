{
  pkgs,
  ...
}:
pkgs.vesktop.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.imagemagick ];
  postPatch = (oldAttrs.postPatch or "") + ''
    convert -coalesce ${
      pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/refs/heads/main/nixos.gif";
        hash = "sha256-XGpc+QhVqBUvNxIarc50y8qvPAHwziR8pLI2TyBWXsQ=";
      }
    } static/splash.webp
  '';
})
