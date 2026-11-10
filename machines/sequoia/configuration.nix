{ self, ... }:
{
  time.timeZone = "America/New_York";

  imports = with self.modules.nixos; [
    self.users.alex.nixosModule

    base
    zsh
    llm-tools
    auto-pressure-gc
    cloudflared
    acme

    ./modules/wildcard-cert.nix
    ./modules/tailscale-exit-node.nix
    ./modules/matrix-synapse.nix
    ./modules/vaultwarden.nix
    ./modules/atlas.nix
    ./modules/ntfy.nix
    ./modules/atuin.nix
    ./modules/paperless.nix
    ./modules/paperless-xerox-ingest.nix
  ];
}
