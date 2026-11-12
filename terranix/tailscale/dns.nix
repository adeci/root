# Split DNS: the homelan's private domains resolve through the trusted VLAN's gateway, reached over the subnet routes approved below.
{
  config,
  lib,
  self,
  safeName,
  ...
}:
let
  inherit (self.resources) homelan;
  router = homelan.router.machine;
in
{
  resource.tailscale_dns_split_nameservers = lib.mapAttrs' (
    domain: _:
    lib.nameValuePair (safeName domain) {
      inherit domain;
      nameservers = [ homelan.vlans.trusted.gateway ];
    }
  ) homelan.dns.records;

  data.tailscale_device.${router}.hostname = router;

  # Approves the homelan VLANs marked `tailnet`; the router advertises the same set.
  resource.tailscale_device_subnet_routes.${router} = {
    device_id = config.data.tailscale_device.${router} "node_id";
    routes = map (vlan: vlan.cidr) (
      lib.attrValues (lib.filterAttrs (_: vlan: vlan.tailnet or false) homelan.vlans)
    );
  };
}
