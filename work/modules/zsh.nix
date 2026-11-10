{
  # Root's zsh feature without the personal git wrapper or Atuin sync.
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
