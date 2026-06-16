# Shared resource data available flake-wide via self.resources.*
{ lib, ... }:
{
  options.flake.resources = lib.mkOption { default = { }; };

  config.flake.resources = {
    b2 = import ../../inventory/resources/b2;
    cloudflare = import ../../inventory/resources/cloudflare;
    homelan = import ../../inventory/resources/homelan;
    llm = import ../../inventory/resources/llm;
    routeros = import ../../inventory/resources/routeros;
  };
}
