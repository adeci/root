# Private names resolve through janus (inventory/resources/homelan/dns.nix);
# tailnet clients reach it over janus's subnet routes.
{
  config,
  lib,
  self,
  ...
}:
let
  inherit (self.resources) homelan;
  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
in
{
  resource.tailscale_dns_split_nameservers = lib.mapAttrs' (
    domain: _:
    lib.nameValuePair (safeName domain) {
      inherit domain;
      nameservers = [ homelan.vlans.trusted.gateway ];
    }
  ) homelan.dns.records;

  data.tailscale_device.janus.hostname = "janus";

  # Same set janus advertises (machines/janus/modules/router/topology.nix).
  resource.tailscale_device_subnet_routes.janus = {
    device_id = config.data.tailscale_device.janus "node_id";
    routes = map (vlan: vlan.cidr) (
      lib.attrValues (lib.filterAttrs (_: vlan: vlan.tailnet or false) homelan.vlans)
    );
  };
}
