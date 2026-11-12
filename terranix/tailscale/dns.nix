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

  # Approves the homelan VLANs marked `tailnet`; the device advertises the same set.
  resource.tailscale_device_subnet_routes.janus = {
    device_id = config.data.tailscale_device.janus "node_id";
    routes = map (vlan: vlan.cidr) (
      lib.attrValues (lib.filterAttrs (_: vlan: vlan.tailnet or false) homelan.vlans)
    );
  };
}
