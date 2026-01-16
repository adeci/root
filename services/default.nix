_:
let
  module_definitions = {
    "@onix/roster" = import ./roster;
    "@onix/tailscale" = import ./tailscale;
    "@onix/vaultwarden" = import ./vaultwarden;
    "@onix/cloudflare-tunnel" = import ./cloudflare-tunnel;
  };
in
module_definitions
