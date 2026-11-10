{
  config,
  wlib,
  pkgs,
  lib,
  ...
}:
let
  jq = lib.getExe pkgs.jq;
  terminalExe = lib.getExe config.terminal;
  # On PATH for config.kdl's spawn binds, which call them by name.
  commands = [
    pkgs.wireplumber
    pkgs.playerctl
    pkgs.brightnessctl
  ]
  ++ lib.optionals (config.terminal != null) [
    config.terminal
    (pkgs.writeShellScriptBin "kitty-here" ''
      set -- $(niri msg -j focused-window 2>/dev/null | ${jq} -r '.app_id, .pid')
      if [ "$1" = kitty ]; then
        child=$(ps -o pid=,tty= --ppid "$2" | grep -v '?' | head -1 | awk '{print $1}')
        [ -n "$child" ] && exec ${terminalExe} -d "$(readlink -f /proc/"$child"/cwd)"
      fi
      exec ${terminalExe}
    '')
  ];
in
{
  options.machineConfig = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      This machine's niri config (outputs, input, extra binds). Written next to
      config.kdl as machine.kdl, which config.kdl includes; validated with it.
    '';
  };

  options.terminal = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    description = ''
      Terminal for the terminal binds, put on niri's PATH together with
      kitty-here. config.kdl spawns it as `kitty`, and kitty-here relies on
      kitty's `-d` flag and app id.
    '';
  };

  imports = [ wlib.wrapperModules.niri ];

  config.package = pkgs.niri.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/refresh-output-identity-on-edid-change.patch
      ./patches/window-scroll-factor-touchpad-only.patch
      ./patches/cursor-shake-to-find.patch
    ];
  });
  config."config.kdl".content = builtins.readFile ./config.kdl;
  config.constructFiles.machineConfig = lib.mkIf (config.machineConfig != "") {
    relPath = "machine.kdl";
    content = config.machineConfig;
  };
  config.drv.meta.platforms = [ "x86_64-linux" ];
  config.prefixVar = [
    {
      data = [
        "PATH"
        ":"
        (lib.makeBinPath commands)
      ];
    }
  ];
}
