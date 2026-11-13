let
  module =
    { self, ... }:
    {
      imports = map (wrapper: wrapper.install) (builtins.attrValues self.wrappers);
    };
in
{
  nixos = module;
  darwin = module;
}
