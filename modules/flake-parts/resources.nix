# Shared resource data available flake-wide via self.resources.*
{ lib, ... }:
{
  options.flake.resources = lib.mkOption { default = { }; };

  config.flake.resources = {
    tunnels = import ../../inventory/resources/cloudflare-tunnels.nix;
  };
}
