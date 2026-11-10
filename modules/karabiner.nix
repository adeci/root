{
  darwin =
    {
      config,
      pkgs,
      lib,
      self,
      ...
    }:
    let
      user = config.system.primaryUser;
      home = config.users.users.${user}.home;

      karabinerConfig = pkgs.writeText "karabiner.json" (
        builtins.toJSON {
          profiles = [
            {
              name = "Default";
              selected = true;
              complex_modifications = {
                rules = [
                  {
                    description = "Keychron Right Alt → Right Command (dictation)";
                    manipulators = [
                      {
                        type = "basic";
                        from.key_code = "right_option";
                        to = [ { key_code = "right_command"; } ];
                        conditions = [
                          {
                            type = "device_if";
                            identifiers = [
                              {
                                vendor_id = 13364;
                                product_id = 563;
                              }
                            ];
                          }
                        ];
                      }
                    ];
                  }
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
      # nix-darwin's module needs Karabiner-Elements 14.13.0, which the pinned
      # package provides.
      services.karabiner-elements = {
        enable = true;
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.karabiner-elements;
      };

      system.activationScripts.postActivation.text = # bash
        lib.mkAfter ''
          echo "installing karabiner config..."
          configDir="${home}/.config/karabiner"
          mkdir -p "$configDir"
          cp "${karabinerConfig}" "$configDir/karabiner.json"
          chmod 644 "$configDir/karabiner.json"
          chown -R ${user}:staff "$configDir"
        '';
    };
}
