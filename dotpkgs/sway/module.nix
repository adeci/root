{
  pkgs,
  wrappers,
  ...
}:
let
  backgroundImage = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_nix.png";
    sha256 = "sha256-W5GaKCOiV2S3NuORGrRaoOE2x9X6gUS+wYf7cQkw9CY=";
  };

  openKittyCwdScript = pkgs.writeShellScript "open-kitty-cwd" (
    builtins.readFile ./scripts/open-kitty-cwd.sh
  );

  swayConfig = pkgs.runCommand "sway-config" { } ''
    substitute ${./config} $out \
      --replace "@backgroundImage@" "${backgroundImage}" \
      --replace "@openKittyCwdScript@" "${openKittyCwdScript}"
  '';
in
{
  sway =
    (wrappers.wrapperModules.sway.apply {
      inherit pkgs;
      configFile.path = swayConfig;
    }).wrapper;
}
