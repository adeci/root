{ pkgs }:
pkgs.runCommand "home-links-tests"
  { nativeBuildInputs = [ (pkgs.callPackage ../package.nix { }) ]; }
  ''
    bash ${./switches.sh}
    touch $out
  ''
