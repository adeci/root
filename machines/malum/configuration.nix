{ self, ... }:
{
  imports = [
    self.users.alex.darwinModule

    ../../modules/darwin/base.nix
    ../../modules/darwin/librewolf.nix
    ../../modules/darwin/karabiner.nix
    ../../modules/darwin/aerospace
    ../../modules/darwin/shopify.nix
    ../../modules/darwin/linux-rosetta-builder.nix
  ];

  # Company laptop — don't publish personal SSH keys or enable sshd
  users.users.alex.openssh.authorizedKeys.keys = [ ];
  services.openssh.enable = false;

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}
