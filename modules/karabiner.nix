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
      imports = [ self.modules.darwin.mac-setup ];

      # nix-darwin's module needs Karabiner-Elements 14.13.0.
      services.karabiner-elements = {
        enable = true;
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.karabiner-elements;
      };

      macSetup.steps =
        let
          bin = "${config.services.karabiner-elements.package}/Library/Application Support/org.pqrs/Karabiner-Elements/bin";
          daemons = [
            "system/org.pqrs.karabiner.karabiner_grabber"
            "system/org.pqrs.karabiner.karabiner_observer"
          ];
        in
        [
          {
            name = "Karabiner driver";
            url = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension";
            instructions = "Driver Extensions (i) > turn on Karabiner-DriverKit-VirtualHIDDevice.";
            check = "/usr/bin/systemextensionsctl list 2>/dev/null | /usr/bin/grep -q 'org.pqrs.Karabiner-DriverKit-VirtualHIDDevice.*activated enabled'";
            restart = daemons;
          }
          {
            name = "Karabiner input monitoring";
            url = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent";
            instructions = "Turn on karabiner_grabber and karabiner_observer.";
            grants =
              map
                (daemon: {
                  service = "kTCCServiceListenEvent";
                  client = "${bin}/${daemon}";
                })
                [
                  "karabiner_grabber"
                  "karabiner_observer"
                ];
            restart = daemons;
          }
        ];

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
