{ self, ... }:
{

  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/cloudflared.nix
    ../../modules/nixos/public-edge.nix

    ./modules/pressroom.nix
  ];

  time.timeZone = "America/New_York";

}
