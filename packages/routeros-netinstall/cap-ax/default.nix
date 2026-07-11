# One-shot provisioning for MikroTik cAP ax (ARM64, WiFi 6).
# Netinstalls RouterOS + wifi-qcom, sets admin password, adds DHCP client.
# Device goes from factory/blank to terraform-ready in one command.
#
# Usage: nix run .#routeros-netinstall-cap-ax
{ pkgs, inputs', ... }:
let
  inherit (inputs'.clan-core.packages) clan-cli;

  version = "7.22.1";
  arch = "arm64";
  netinstall-cli = import ../netinstall-cli.nix { inherit pkgs; };

  routeros = pkgs.fetchurl {
    url = "https://download.mikrotik.com/routeros/${version}/routeros-${version}-${arch}.npk";
    hash = "sha256-pfyYQKeoeDLYHpaZzqga6Wmz2SSEegtFNpdOWlibIGc=";
  };

  wifi-qcom = pkgs.fetchurl {
    url = "https://download.mikrotik.com/routeros/${version}/wifi-qcom-${version}-${arch}.npk";
    hash = "sha256-6npDjebffBOnASLOiAWNjCyppdGdsAPd20HDjs6+dZU=";
  };
in
pkgs.writeShellApplication {
  name = "routeros-netinstall-cap-ax";
  runtimeInputs = [
    pkgs.iproute2
    pkgs.iptables
    pkgs.python3
    clan-cli
  ];
  text = # bash
    ''
      exec python3 ${../netinstall.py} \
        --device "cAP ax" \
        --arch ${arch} \
        --version ${version} \
        --netinstall-cli ${netinstall-cli}/bin/netinstall-cli \
        --package ${routeros} \
        --package-name routeros-${version}-${arch}.npk \
        --package ${wifi-qcom} \
        --package-name wifi-qcom-${version}-${arch}.npk \
        --dhcp-client ether1 \
        --installed-summary "RouterOS ${version} (${arch}) + wifi-qcom" \
        --dhcp-summary ether1 \
        --completion-note "Plug ether1 into management network, then net-apply."
    '';
  meta.platforms = pkgs.lib.platforms.linux;
}
