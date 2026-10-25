{ self, ... }:
{
  resource.tailscale_acl.policy = {
    acl = builtins.readFile self.resources.tailscale.policy;
  };

  # Adopts the policy file that was set in the admin console.
  import = [
    {
      to = "tailscale_acl.policy";
      id = "acl";
    }
  ];
}
