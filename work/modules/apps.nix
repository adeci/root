let
  # SSH uses the TPM agent (Linux) or Secretive (Mac) instead.
  shared = {
    programs._1password.enable = true;
    programs._1password-gui.enable = true;
  };
in
{
  nixos =
    { config, ... }:
    {
      imports = [ shared ];

      programs._1password-gui.polkitPolicyOwners = [ config.system.primaryUser ];
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
