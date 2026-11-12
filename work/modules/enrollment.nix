{
  nixos =
    {
      config,
      pkgs,
      self,
      workInputs,
      ...
    }:
    {
      # Run `enroll` once after the first activation.
      imports = [ workInputs.shopify-framework.nixosModules.default ];

      shopify-framework = {
        enable = true;
        user = config.system.primaryUser;
        idpUsername = self.users.alex-work.email;
        developerTools.enable = true;
        # Replaces the default apps, whose plain 1Password lacks polkit owners.
        packages.apps = [ pkgs.slack ];
      };
    };
}
