{
  inputs,
  self,
  ...
}:
{
  # Run `enroll` once after the first activation.
  imports = [ inputs.shopify-framework.nixosModules.default ];

  shopify-framework = {
    enable = true;
    user = self.users.alex-work.username;
    idpUsername = self.users.alex-work.email;
    developerTools.enable = true;
  };
}
