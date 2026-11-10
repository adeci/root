let
  # SSH uses the TPM agent (Linux) or Secretive (Mac) instead.
  shared = {
    programs._1password.enable = true;
    programs._1password-gui.enable = true;
  };
in
{
  nixos =
    { pkgs, self, ... }:
    {
      imports = [ shared ];

      programs._1password-gui.polkitPolicyOwners = [ self.users.alex-work.username ];

      # Without the framework's plain 1Password, which lacks the polkit owners
      shopify-framework.packages.apps = [ pkgs.slack ];
    };

  # 1Password's module copies the app into /Applications, where it must live.
  darwin =
    { pkgs, ... }:
    {
      imports = [ shared ];

      environment.systemPackages = [
        pkgs.google-cloud-sdk
        pkgs.slack
      ];
    };
}
