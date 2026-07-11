{
  wlib,
  pkgs,
  lib,
  self,
  ...
}:
let
  wrappedNiri = self.wrappers.niri.wrap { inherit pkgs; };
  wrappedKitty = self.wrappers.kitty.wrap { inherit pkgs; };
  wrappedNoctalia = self.wrappers.noctalia-shell.wrap { inherit pkgs; };
  wrappedZsh = self.wrappers.zsh.wrap { inherit pkgs; };
in
{
  imports = [ wlib.modules.default ];

  config.package = wrappedNiri;
  config.binName = "niri";

  config.prefixVar = [
    {
      data = [
        "PATH"
        ":"
        (lib.makeBinPath [
          wrappedKitty
          wrappedNoctalia
          wrappedZsh
        ])
      ];
    }
  ];
}
