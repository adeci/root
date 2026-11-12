{ lib, pkgs, ... }:
let
  version = "7.22.1";

  # Statically linked, so it runs without patchelf.
  netinstall-cli = pkgs.stdenvNoCC.mkDerivation {
    pname = "netinstall-cli";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://download.mikrotik.com/routeros/${version}/netinstall-${version}.tar.gz";
      hash = "sha256-qy+4b4X7p4nICpeD12PpjrsWtdeFjQDSAip8Unj2zbU=";
    };
    sourceRoot = ".";
    dontBuild = true;
    installPhase = "install -Dm755 netinstall-cli $out/bin/netinstall-cli";
    meta.platforms = lib.platforms.linux;
  };

  # Hashes of this version's packages, by package name and architecture.
  npkHashes = {
    routeros-arm = "sha256-lQCnt2vusjy1/tCmUZ4dvGzccnj4rOe+LIdQQcLElvw=";
    routeros-arm64 = "sha256-pfyYQKeoeDLYHpaZzqga6Wmz2SSEegtFNpdOWlibIGc=";
    wifi-qcom-arm64 = "sha256-6npDjebffBOnASLOiAWNjCyppdGdsAPd20HDjs6+dZU=";
  };
in
pkgs.writeShellApplication {
  name = "routeros-netinstall";
  runtimeInputs = [
    pkgs.iproute2
    pkgs.iptables
    pkgs.python3
  ];
  text = ''
    exec python3 ${./netinstall.py} --version ${version} --netinstall-cli ${netinstall-cli}/bin/netinstall-cli "$@"
  '';
  # One of this version's package files, e.g. `npk "arm64" "wifi-qcom"`.
  passthru.npk =
    arch: name:
    pkgs.fetchurl {
      url = "https://download.mikrotik.com/routeros/${version}/${name}-${version}-${arch}.npk";
      hash = npkHashes."${name}-${arch}";
    };
  meta.platforms = [ "x86_64-linux" ];
}
