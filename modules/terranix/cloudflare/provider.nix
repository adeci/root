# Cloudflare provider, credentials, zone data sources
{
  config,
  self,
  self',
  lib,
  ...
}:
let
  inherit (self.resources.cloudflare) zones;
  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
in
{
  terraform.required_providers.cloudflare = {
    source = "cloudflare/cloudflare";
    version = "~> 4.0";
  };

  terraform.required_providers.random = {
    source = "hashicorp/random";
  };

  data.external.cloudflare-api-token = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "cloudflare-api-token"
    ];
  };

  data.external.cloudflare-account-id = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "cloudflare-account-id"
    ];
  };

  provider.cloudflare = {
    api_token = config.data.external.cloudflare-api-token "result.secret";
  };

  data.cloudflare_zone = lib.listToAttrs (
    map (zone: {
      name = safeName zone;
      value.name = zone;
    }) zones
  );
}
