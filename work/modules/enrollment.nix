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
      imports = [
        self.modules.nixos.primary-user
        # Run `enroll` once after the first activation.
        workInputs.shopify-framework.nixosModules.default
      ];

      shopify-framework = {
        enable = true;
        user = config.system.primaryUser;
        idpUsername = config.system.primaryUserProfile.email;
        developerTools.enable = true;
        # Replaces the default apps, whose plain 1Password lacks polkit owners.
        packages.apps = [ pkgs.slack ];
      };
    };
}
