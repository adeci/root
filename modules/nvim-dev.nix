{
  nixos =
    { self, ... }:
    {
      imports = [ self.modules.nixos.wrappers ];
      wrappers.nvim.languageServers = true;
    };

  darwin =
    { self, ... }:
    {
      imports = [ self.modules.darwin.wrappers ];
      wrappers.nvim.languageServers = true;
    };
}
