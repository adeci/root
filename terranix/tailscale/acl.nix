{ self, ... }:
{
  resource.tailscale_acl.policy = {
    acl = builtins.toJSON self.resources.tailscale.policy;
  };
}
