{
  config,
  self',
  lib,
  ...
}:
{
  terraform.required_providers.tailscale = {
    source = "tailscale/tailscale";
    version = "~> 0.29";
  };

  data.external.tailscale-oauth-client-id = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "tailscale-oauth-client-id"
    ];
  };

  data.external.tailscale-oauth-client-secret = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "tailscale-oauth-client-secret"
    ];
  };

  provider.tailscale = {
    oauth_client_id = config.data.external.tailscale-oauth-client-id "result.secret";
    oauth_client_secret = config.data.external.tailscale-oauth-client-secret "result.secret";
    tailnet = "-";
  };
}
