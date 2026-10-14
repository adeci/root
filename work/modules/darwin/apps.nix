{ self, pkgs, ... }:
{
  environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.handy ];

  homebrew.casks = [
    "1password"
    "1password-cli"
    "gcloud-cli"
    "slack"
  ];
}
