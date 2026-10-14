{ self, workUsers, ... }:
{
  imports = [
    workUsers.alex.darwinModule

    ../../modules/darwin/managed-device.nix
    ../../modules/darwin/apps.nix
    ../../modules/darwin/shell.nix

    (self + "/modules/darwin/base.nix")
    (self + "/modules/darwin/librewolf.nix")
    (self + "/modules/darwin/llm-config.nix")
    (self + "/modules/darwin/karabiner.nix")
    (self + "/modules/darwin/mouse.nix")
    (self + "/modules/darwin/aerospace")
    (self + "/modules/darwin/linux-rosetta-builder.nix")
    (self + "/modules/darwin/secretive.nix")
  ];

  # Work keys only; Clan deploys as root.
  users.users.root.openssh.authorizedKeys.keys = workUsers.alex.sshKeys;
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      AuthorizedKeysFile none
    '';
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}
