{ pkgs, workUsers, ... }:
{
  # SSH uses the TPM agent instead
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ workUsers.alex.username ];
  };

  # Without the framework's plain 1Password, which lacks the polkit owners
  shopify-framework.packages.apps = [ pkgs.slack ];
}
