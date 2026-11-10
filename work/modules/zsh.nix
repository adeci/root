{
  nixos =
    { lib, self, ... }:
    {
      imports = [ self.modules.nixos.zsh ];

      wrappers.zsh = {
        git = null;
        atuinSync = false;
      };
      wrappers.git.enable = lib.mkForce false;
    };
}
