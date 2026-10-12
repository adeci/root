{ self, pkgs, ... }:
{
  environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.handy ];

  homebrew.casks = [
    "1password"
    "1password-cli"
    "gcloud-cli"
    "slack"
  ];

  # 1Password SSH agent
  environment.etc."ssh/ssh_config.d/shopify".text = # ssh_config
    ''
      Host *
        AddKeysToAgent yes
        IdentityAgent "/Users/alex/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    '';
}
