{
  # Boot, shutdown and the LUKS prompt as a live tree of systemd jobs on the console.
  nixos =
    { inputs, ... }:
    {
      imports = [ inputs.bootvine.nixosModules.default ];

      services.bootvine.enable = true;
    };
}
