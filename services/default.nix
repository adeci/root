{ inputs, ... }:
let
  module_definitions = {
    # External service modules
    "@onix/roster" = inputs.roster.clanModules."@onix/roster";

    # Local service modules
    "@onix/tailscale" = import ./tailscale;
    "@onix/vaultwarden" = import ./vaultwarden;
    "@onix/cloudflare-tunnel" = import ./cloudflare-tunnel;
    "@onix/siteup" = import ./siteup;
  };
in
module_definitions
