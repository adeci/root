{
  config,
  lib,
  self',
  ...
}:
let
  inherit (import ../lib.nix { inherit config lib self'; }) clanSecret;
in
{
  imports = [
    ./zones.nix
    ./tunnels.nix
    ./dns.nix
    ./rulesets.nix
  ];

  terraform.required_providers.cloudflare = {
    source = "cloudflare/cloudflare";
    version = "~> 4.0";
  };

  terraform.required_providers.random = {
    source = "hashicorp/random";
    version = "~> 3.9";
  };

  clanSecrets = [
    "cloudflare-api-token"
    "cloudflare-account-id"
  ];

  provider.cloudflare = {
    api_token = clanSecret "cloudflare-api-token";
  };
}
