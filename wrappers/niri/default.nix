{
  config,
  wlib,
  pkgs,
  lib,
  ...
}:
let
  kitty-here = pkgs.writeShellApplication {
    name = "kitty-here";
    runtimeInputs = [ pkgs.jq ];
    runtimeEnv.KITTY = lib.getExe config.terminal;
    text = builtins.readFile ./kitty-here.sh;
  };

  # On PATH for config.kdl's spawn binds, which call them by name.
  commands = [
    pkgs.wireplumber
    pkgs.playerctl
    pkgs.brightnessctl
  ]
  ++ lib.optionals (config.terminal != null) [
    config.terminal
    kitty-here
  ];
in
{
  imports = [ wlib.wrapperModules.niri ];

  options.machineConfig = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "This machine's niri config (outputs, input, extra binds); config.kdl includes it as machine.kdl.";
  };

  options.terminal = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    description = "Terminal for the terminal binds and kitty-here, which expect kitty's binary name, `-d` flag and app id.";
  };

  config = {
    package = pkgs.niri.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./patches/refresh-output-identity-on-edid-change.patch
        ./patches/window-scroll-factor-touchpad-only.patch
        ./patches/cursor-shake-to-find.patch
      ];
    });
    "config.kdl".content = builtins.readFile ./config.kdl;
    constructFiles.machineConfig = lib.mkIf (config.machineConfig != "") {
      relPath = "machine.kdl";
      content = config.machineConfig;
    };
    drv.meta.platforms = [ "x86_64-linux" ];
    prefixVar = [
      {
        data = [
          "PATH"
          ":"
          (lib.makeBinPath commands)
        ];
      }
    ];
  };
}
