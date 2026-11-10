{
  # nvim with the small language servers, instead of base's plain nvim.
  nixos =
    { lib, self, ... }:
    {
      imports = [ self.modules.nixos.wrappers ];

      wrappers.nvim-dev.enable = true;
      wrappers.nvim.enable = lib.mkForce false;
    };
}
