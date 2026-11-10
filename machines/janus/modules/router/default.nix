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
    ./probes.nix
    ./routeros-metrics.nix
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
