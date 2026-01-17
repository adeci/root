_:
let
  module_definitions = {
    "@onix/roster" = import ./roster;
    "@onix/tailscale" = import ./tailscale;
    "@onix/vaultwarden" = import ./vaultwarden;
    "@onix/cloudflare-tunnel" = import ./cloudflare-tunnel;
    "@onix/siteup" = import ./siteup;
  };
in
module_definitions
