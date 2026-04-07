# MikroTik Netinstall CLI — static Linux binary.
# Shared across all device netinstall packages.
{ pkgs }:
let
  version = "7.22.1";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "netinstall-cli";
  inherit version;
  src = pkgs.fetchurl {
    url = "https://download.mikrotik.com/routeros/${version}/netinstall-${version}.tar.gz";
    hash = "sha256-qy+4b4X7p4nICpeD12PpjrsWtdeFjQDSAip8Unj2zbU=";
  };
  sourceRoot = ".";
  dontBuild = true;
  installPhase = "install -Dm755 netinstall-cli $out/bin/netinstall-cli";
  meta.platforms = pkgs.lib.platforms.linux;
}
