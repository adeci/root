{ self, ... }:
{
  imports = [ ../../modules/nixos/clan-installer.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # shopkey lets work machines install from this stick too.
  users.users.root.openssh.authorizedKeys.keys = self.users.alex.sshKeys ++ [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClADO9vF1WDZmhaCDvvzq43FlbZ9n2y3+QHSs0pnwRq shopkey"
  ];
}
