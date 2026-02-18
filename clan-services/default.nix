_:
let
  module_definitions = {
    "@adeci/roster" = import ./roster;

    # Local service modules
    "@adeci/tailscale" = import ./tailscale;
    "@adeci/vaultwarden" = import ./vaultwarden;
    "@adeci/cloudflare-tunnel" = import ./cloudflare-tunnel;
    "@adeci/siteup" = import ./siteup;
  };
in
module_definitions
