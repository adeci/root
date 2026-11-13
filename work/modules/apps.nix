let
  # SSH goes through hardware-backed agents, not 1Password's.
  shared = {
    programs._1password.enable = true;
    programs._1password-gui.enable = true;
  };
in
{
  nixos =
    { config, self, ... }:
    {
      imports = [
        self.modules.nixos.primary-user
        shared
      ];

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
