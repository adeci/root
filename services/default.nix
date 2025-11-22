_:
let
  module_definitions = {
    "@onix/roster" = import ./roster;
    "@onix/tailscale" = import ./tailscale;
  };
in
module_definitions
