let
  module =
    class:
    { self, ... }:
    {
      imports = [ self.modules.${class}.wrappers ];
      wrappers.nvim.languageServers = true;
    };
in
{
  nixos = module "nixos";
  darwin = module "darwin";
}
