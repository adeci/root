{ self, ... }:
{
  time.timeZone = "America/New_York";

  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/cloudflared.nix
    ../../modules/nixos/acme.nix

    ./modules/tailscale-exit-node.nix
    ./modules/matrix-synapse.nix
    ./modules/vaultwarden.nix
    ./modules/forgejo.nix
    ./modules/litellm.nix
    ./modules/atlas.nix
    ./modules/ntfy.nix
    ./modules/atuin.nix
    ./modules/paperless.nix
    ./modules/paperless-xerox-ingest.nix
  ];
}
