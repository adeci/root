{ self, ... }:
{
  resource.tailscale_acl.policy = {
    acl = builtins.readFile self.resources.tailscale.policy;
  };
}
