{ self, ... }:
{
  home-manager.users.alex = import ./home.nix;

  time.timeZone = "America/New_York";

  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/home-manager.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/dev.nix
    ../../modules/nixos/cloudflared.nix

    ./modules/matrix-synapse.nix
    ./modules/vaultwarden.nix
    ./modules/opencrow
    ./modules/atuin.nix
  ];
}
