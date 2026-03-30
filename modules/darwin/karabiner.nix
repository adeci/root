# caps lock as escape (tap)
# control (hold)
# on all keyboards
{
  config,
  pkgs,
  lib,
  ...
}:
let
  user = config.system.primaryUser;

  karabinerConfig = pkgs.writeText "karabiner.json" (
    builtins.toJSON {
      profiles = [
        {
          name = "Default";
          selected = true;
          complex_modifications = {
            rules = [
              {
                description = "Caps Lock → Escape (tap) / Control (hold)";
                manipulators = [
                  {
                    type = "basic";
                    from = {
                      key_code = "caps_lock";
                      modifiers = {
                        optional = [ "any" ];
                      };
                    };
                    to = [ { key_code = "left_control"; } ];
                    to_if_alone = [ { key_code = "escape"; } ];
                  }
                ];
              }
            ];
          };
          virtual_hid_keyboard = {
            keyboard_type_v2 = "ansi";
          };
        }
      ];
    }
  );
in
{
  homebrew.casks = [ "karabiner-elements" ];

  system.activationScripts.postActivation.text = # bash
    lib.mkAfter ''
      echo "installing karabiner config..."
      configDir="/Users/${user}/.config/karabiner"
      mkdir -p "$configDir"
      cp "${karabinerConfig}" "$configDir/karabiner.json"
      chmod 644 "$configDir/karabiner.json"
      chown -R ${user}:staff "$configDir"
    '';
}
