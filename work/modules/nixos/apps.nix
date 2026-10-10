{ workUsers, ... }:
{
  # SSH uses the TPM agent instead
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ workUsers.alex.username ];
  };
}
