# One-shot provisioning for MikroTik CRS310-8G+2S+IN (ARM, upstairs switch).
# Netinstalls RouterOS, sets admin password, adds DHCP client.
# Device goes from factory/blank to terraform-ready in one command.
#
# Usage: nix run .#routeros-netinstall-crs310
{ pkgs, inputs', ... }:
let
  inherit (inputs'.clan-core.packages) clan-cli;

  version = "7.22.1";
  arch = "arm";
  netinstall-cli = import ../netinstall-cli.nix { inherit pkgs; };

  routeros = pkgs.fetchurl {
    url = "https://download.mikrotik.com/routeros/${version}/routeros-${version}-${arch}.npk";
    hash = "sha256-lQCnt2vusjy1/tCmUZ4dvGzccnj4rOe+LIdQQcLElvw=";
  };
in
pkgs.writeShellApplication {
  name = "routeros-netinstall-crs310";
  runtimeInputs = [
    pkgs.iproute2
    pkgs.iptables
    pkgs.python3
    clan-cli
  ];
  text = # bash
    ''
      exec python3 ${../netinstall.py} \
        --device "CRS310-8G+2S+IN" \
        --arch ${arch} \
        --version ${version} \
        --netinstall-cli ${netinstall-cli}/bin/netinstall-cli \
        --package ${routeros} \
        --package-name routeros-${version}-${arch}.npk \
        --dhcp-client ether1 \
        --dhcp-client sfp-sfpplus1 \
        --installed-summary "RouterOS ${version} (${arch})" \
        --dhcp-summary "ether1 and sfp-sfpplus1" \
        --completion-note "Plug ether1 or sfp-sfpplus1 into the network, then net-apply."
    '';
  meta.platforms = pkgs.lib.platforms.linux;
}
