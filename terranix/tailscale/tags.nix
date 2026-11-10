{
  config,
  lib,
  self,
  ...
}:
let
  inherit (self.resources.tailscale) deviceTags;
in
{
  data.tailscale_device = lib.mapAttrs (hostname: _: { inherit hostname; }) deviceTags;

  resource.tailscale_device_tags = lib.mapAttrs (hostname: tags: {
    device_id = config.data.tailscale_device.${hostname} "node_id";
    inherit tags;
    # Tags must exist in the policy before a device can carry them.
    depends_on = [ "tailscale_acl.policy" ];
  }) deviceTags;
}
