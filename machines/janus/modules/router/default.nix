{ lib, self, ... }:
let
  tailnetVlans = lib.filter (vlan: vlan.tailnet) (lib.attrValues self.inventory.lan.vlans);
  advertiseRoutes = "--advertise-routes=${
    lib.concatMapStringsSep "," (vlan: vlan.cidr) tailnetVlans
  }";
in
{
  imports = [
    ./networkd.nix
    ./firewall.nix
    ./dhcp-dns.nix
    ./probes.nix
    ./routeros-metrics.nix
  ];

  services.tailscale = {
    extraUpFlags = [ advertiseRoutes ];
    extraSetFlags = [
      "--accept-routes=false"
      advertiseRoutes
    ];
    useRoutingFeatures = "server";
  };
}
