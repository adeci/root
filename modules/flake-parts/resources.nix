# Shared resource data available flake-wide via self.resources.*
{ lib, ... }:
{
  options.flake.resources = lib.mkOption { default = { }; };

  config.flake.resources = {
    cloudflare = import ../../inventory/resources/cloudflare;
    routeros = import ../../inventory/resources/routeros;
  };
}
