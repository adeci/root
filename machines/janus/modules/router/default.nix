# janus — NixOS router (Qotom Q20321G9)
# WAN (DHCP from ISP) -> VLAN trunk to switches -> inter-VLAN routing + NAT
#
# Qotom Q20321G9 port map, profiled 2026-04-12 by plug-testing.
#
# 2.5G RJ45 (igc driver):
#                        Label Eth3 = enp4s0    Label Eth4 = enp5s0
#   Label Eth5 = enp8s0  Label Eth1 = enp6s0    Label Eth2 = enp7s0
#
# SFP+ right side (ixgbe driver, 10G):
#   Right-top    = eno2
#   Right-bottom = eno1
{
  lib,
  self,
  ...
}:
let
  topology = import ./topology.nix { inherit lib self; };
in
{
  imports = [
    ./validation.nix
    ./networkd.nix
    ./firewall.nix
    ./dhcp-dns.nix
  ];

  services.tailscale = {
    extraUpFlags = [ topology.tailscaleRouteFlag ];
    extraSetFlags = [
      "--accept-routes=false"
      topology.tailscaleRouteFlag
    ];
    useRoutingFeatures = "server";
  };
}
