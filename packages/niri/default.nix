{
  config,
  wlib,
  pkgs,
  lib,
  ...
}:
let
  jq = lib.getExe pkgs.jq;
  # Called by name from config.kdl, so a thawed config needs no store paths.
  commands = [
    pkgs.wireplumber
    pkgs.playerctl
    pkgs.brightnessctl
    (pkgs.writeShellScriptBin "kitty-here" ''
      set -- $(niri msg -j focused-window 2>/dev/null | ${jq} -r '.app_id, .pid')
      if [ "$1" = kitty ]; then
        child=$(ps -o pid=,tty= --ppid "$2" | grep -v '?' | head -1 | awk '{print $1}')
        [ -n "$child" ] && exec kitty -d "$(readlink -f /proc/"$child"/cwd)"
      fi
      exec kitty
    '')
  ];
in
{
  imports = [
    wlib.wrapperModules.niri
    ../thaw/wrapper.nix
  ];

  config.package = pkgs.niri.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/refresh-output-identity-on-edid-change.patch
      ./patches/window-scroll-factor-touchpad-only.patch
      ./patches/cursor-shake-to-find.patch
    ];
  });
  config."config.kdl".content = builtins.readFile ./config.kdl;
  config.thaw.files."config.kdl" = ./config.kdl;
  config.thaw.optional = [ "machine.kdl" ];
  config.env.NIRI_CONFIG = lib.mkForce {
    data = "${config.thaw.dir}/config.kdl";
    esc-fn = wlib.escapeShellArgWithEnv;
  };
  # niri watches its config, so the /etc flip of a rebuild reloads it.
  config.disableConfigHotReload = true;
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
