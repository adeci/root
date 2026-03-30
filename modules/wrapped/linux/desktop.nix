{
  wlib,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  wrappedNiri = inputs.self.wrappers.niri.wrap { inherit pkgs; };
  wrappedKitty = inputs.self.wrappers.kitty.wrap { inherit pkgs; };
  wrappedNoctalia = inputs.self.wrappers.noctalia-shell.wrap { inherit pkgs; };
  wrappedZsh = inputs.self.wrappers.zsh.wrap { inherit pkgs; };
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
