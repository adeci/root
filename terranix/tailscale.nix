{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (self.inventory) lan tailscalePolicy;
  inherit (self.inventory.tailnet) deviceTags;
  inherit (import ./lib.nix { inherit config lib self'; }) clanSecret safeName;
  router = self.inventory.router.machine;
in
{
  terraform.required_providers.tailscale = {
    source = "tailscale/tailscale";
    version = "~> 0.29";
  };

  clanSecrets = [
    "tailscale-oauth-client-id"
    "tailscale-oauth-client-secret"
  ];

  provider.tailscale = {
    oauth_client_id = clanSecret "tailscale-oauth-client-id";
    oauth_client_secret = clanSecret "tailscale-oauth-client-secret";
    tailnet = "-";
  };

  resource.tailscale_acl.policy = {
    acl = builtins.toJSON tailscalePolicy;
  };

  data.tailscale_device = lib.genAttrs (lib.attrNames deviceTags ++ [ router ]) (hostname: {
    inherit hostname;
  });

  resource.tailscale_device_tags = lib.mapAttrs (hostname: tags: {
    device_id = config.data.tailscale_device.${hostname} "node_id";
    inherit tags;
    # Tags must exist in the policy before a device can carry them.
    depends_on = [ "tailscale_acl.policy" ];
  }) deviceTags;

  # Split DNS: the LAN's private domains resolve through the trusted VLAN's gateway, reached over the subnet routes approved below.
  resource.tailscale_dns_split_nameservers = lib.mapAttrs' (
    domain: _:
    lib.nameValuePair (safeName domain) {
      inherit domain;
      nameservers = [ lan.vlans.trusted.gateway ];
    }
  ) lan.dns;

  # Approves the LAN's VLANs marked `tailnet`; the router advertises the same set.
  resource.tailscale_device_subnet_routes.${router} = {
    device_id = config.data.tailscale_device.${router} "node_id";
    routes = map (vlan: vlan.cidr) (lib.attrValues (lib.filterAttrs (_: vlan: vlan.tailnet) lan.vlans));
  };
}
