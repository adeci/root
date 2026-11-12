{ clanSecret, ... }:
{
  terraform.required_providers.tailscale = {
    source = "tailscale/tailscale";
    version = "~> 0.29";
  };

  clanSecrets = [
    "tailscale-oauth-client-id"
    "tailscale-oauth-client-secret"
  ];

  provider.tailscale = {
    oauth_client_id = clanSecret "tailscale-oauth-client-id";
    oauth_client_secret = clanSecret "tailscale-oauth-client-secret";
    tailnet = "-";
  };
}
