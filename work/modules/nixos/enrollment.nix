{ workInputs, workUsers, ... }:
{
  # Run `enroll` once after the first activation.
  imports = [ workInputs.shopify-framework.nixosModules.default ];

  shopify-framework = {
    enable = true;
    user = workUsers.alex.username;
    idpUsername = workUsers.alex.email;
    developerTools.enable = true;
  };
}
