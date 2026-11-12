{
  config,
  self,
  lib,
  safeName,
  clanSecret,
  ...
}:
let
  inherit (self.resources.cloudflare) zones;
in
{
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

  data.cloudflare_zone = lib.listToAttrs (
    map (zone: {
      name = safeName zone;
      value.name = zone;
    }) zones
  );

  _module.args = {
    zoneId = zone: config.data.cloudflare_zone.${safeName zone} "id";

    # The zone a hostname is in (the longest that matches), and its record name there: "@" at the apex.
    hostnameParts =
      hostname:
      let
        matches = lib.filter (zone: hostname == zone || lib.hasSuffix ".${zone}" hostname) zones;
        longestFirst = lib.sort (a: b: lib.stringLength a > lib.stringLength b) matches;
        zone = lib.head longestFirst;
      in
      if matches == [ ] then
        throw "Cloudflare hostname ${hostname} is in none of the configured zones"
      else
        {
          inherit zone;
          name = if hostname == zone then "@" else lib.removeSuffix ".${zone}" hostname;
        };
  };
}
