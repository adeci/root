let
  # A plain system git instead of the git wrapper, and no shell history sync.
  shared =
    { lib, ... }:
    {
      wrappers.zsh = {
        git = null;
        atuinSyncAddress = null;
      };
      wrappers.git.enable = lib.mkForce false;
    };
in
{
  nixos =
    { self, ... }:
    {
      imports = [
        self.modules.nixos.zsh
        shared
      ];
    };

  darwin =
    { pkgs, self, ... }:
    {
      imports = [
        self.modules.darwin.zsh
        shared
      ];

      environment.systemPackages = [ pkgs.git ];
    };
}
