{
  clan-cli,
  lib,
  ...
}:
let
  inherit (import ../lib.nix { inherit clan-cli lib; }) clanSecret;
in
{
  imports = [
    ./zones.nix
    ./tunnels.nix
    ./dns.nix
    ./rulesets.nix
  ];

  clanSecrets = [
    "cloudflare-api-token"
    "cloudflare-account-id"
  ];

  provider.cloudflare = {
    api_token = clanSecret "cloudflare-api-token";
  };
}
