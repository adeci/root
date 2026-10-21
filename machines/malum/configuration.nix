{
  self,
  ...
}:
{
  imports = [
    self.users.alex-work.darwinModule

    ../../modules/darwin/work/managed-device.nix
    ../../modules/darwin/work/apps.nix
    ../../modules/darwin/work/shell.nix

    ../../modules/darwin/base.nix
    ../../modules/darwin/librewolf.nix
    ../../modules/darwin/llm-config.nix
    ../../modules/darwin/handy.nix
    ../../modules/darwin/karabiner.nix
    ../../modules/darwin/mouse.nix
    ../../modules/darwin/aerospace
    ../../modules/darwin/linux-rosetta-builder.nix
    ../../modules/darwin/secretive.nix
  ];

  # Work keys only; Clan deploys as root.
  users.users.root.openssh.authorizedKeys.keys = self.users.alex-work.sshKeys;
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
