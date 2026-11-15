{
  nixos =
    { inputs, ... }:
    {
      imports = [ inputs.earwig.nixosModules.default ];

      services.earwig.enable = true;
    };

  darwin =
    { inputs, ... }:
    {
      imports = [ inputs.earwig.darwinModules.default ];

      services.earwig.enable = true;
    };
}
