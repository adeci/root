{ self, ... }:
{
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
    ./modules/matrix-synapse
    ./modules/vaultwarden
    ./modules/atlas.nix
    ./modules/ntfy.nix
    ./modules/paperless
    ./modules/paperless-xerox-ingest.nix
  ];

  cloudflared.token = self.inventory.cloudflare.tunnelToken;
  acme.tokenGenerator = self.inventory.cloudflare.acmeTokenGenerator;
}
