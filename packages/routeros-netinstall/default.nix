{ pkgs, inputs', ... }:
let
  inherit (inputs'.clan-core.packages) clan-cli;

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
    meta.platforms = pkgs.lib.platforms.linux;
  };

  npk =
    name: arch: hash:
    pkgs.fetchurl {
      url = "https://download.mikrotik.com/routeros/${version}/${name}-${version}-${arch}.npk";
      inherit hash;
    };

  netinstall =
    {
      name,
      device,
      arch,
      packages,
      args,
    }:
    let
      flags = [
        ''--device "${device}"''
        "--arch ${arch}"
        "--version ${version}"
        "--netinstall-cli ${netinstall-cli}/bin/netinstall-cli"
      ]
      ++ pkgs.lib.concatMap (p: [
        "--package ${npk p.name arch p.hash}"
        "--package-name ${p.name}-${version}-${arch}.npk"
      ]) packages
      ++ args;
    in
    pkgs.writeShellApplication {
      name = "routeros-netinstall-${name}";
      runtimeInputs = [
        pkgs.iproute2
        pkgs.iptables
        pkgs.python3
        clan-cli
      ];
      text = "exec python3 ${./netinstall.py} \\\n  ${pkgs.lib.concatStringsSep " \\\n  " flags}\n";
      meta.platforms = [ "x86_64-linux" ];
    };
in
{
  cap-ax = netinstall {
    name = "cap-ax";
    device = "cAP ax";
    arch = "arm64";
    packages = [
      {
        name = "routeros";
        hash = "sha256-pfyYQKeoeDLYHpaZzqga6Wmz2SSEegtFNpdOWlibIGc=";
      }
      {
        name = "wifi-qcom";
        hash = "sha256-6npDjebffBOnASLOiAWNjCyppdGdsAPd20HDjs6+dZU=";
      }
    ];
    args = [
      "--dhcp-client ether1"
      ''--installed-summary "RouterOS ${version} (arm64) + wifi-qcom"''
      "--dhcp-summary ether1"
      ''--completion-note "Plug ether1 into the management network, then apply its configuration."''
    ];
  };

  crs310 = netinstall {
    name = "crs310";
    device = "CRS310-8G+2S+IN";
    arch = "arm";
    packages = [
      {
        name = "routeros";
        hash = "sha256-lQCnt2vusjy1/tCmUZ4dvGzccnj4rOe+LIdQQcLElvw=";
      }
    ];
    args = [
      "--dhcp-client ether1"
      "--dhcp-client sfp-sfpplus1"
      ''--installed-summary "RouterOS ${version} (arm)"''
      ''--dhcp-summary "ether1 and sfp-sfpplus1"''
      ''--completion-note "Plug ether1 or sfp-sfpplus1 into the network, then apply its configuration."''
    ];
  };

  crs328 = netinstall {
    name = "crs328";
    device = "CRS328-24P-4S+RM";
    arch = "arm";
    packages = [
      {
        name = "routeros";
        hash = "sha256-lQCnt2vusjy1/tCmUZ4dvGzccnj4rOe+LIdQQcLElvw=";
      }
    ];
    args = [
      "--dhcp-client ether1"
      ''--installed-summary "RouterOS ${version} (arm)"''
      "--dhcp-summary ether1"
      ''--completion-note "Plug ether1 into the management network, then apply its configuration."''
    ];
  };
}
