{
  nixos =
    { self, ... }:
    {
      imports = map (wrapper: wrapper.install) (builtins.attrValues self.wrappers);
    };

  darwin =
    { self, ... }:
    {
      imports = map (wrapper: wrapper.install) (builtins.attrValues self.wrappers);
    };
}
