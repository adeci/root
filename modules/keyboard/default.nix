{
  nixos = {
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings.main.capslock = "overload(control, esc)";
        extraConfig = builtins.readFile ./cleaning-lock.conf;
      };
    };
  };

  darwin =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      asUser = config.system.asPrimaryUser;
      configDir = "${config.system.primaryUserHome}/.config/karabiner";
    in
    {
      imports = [
        self.modules.darwin.mac-setup
        self.modules.darwin.primary-user
      ];

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

      # A copy, not a home.links link: Karabiner misses changes to a linked karabiner.json.
      # Made as the user, so a missing ~/.config does not end up owned by root.
      system.activationScripts.postActivation.text = # bash
        lib.mkAfter ''
          echo "installing karabiner config..."
          ${asUser} /bin/mkdir -p ${lib.escapeShellArg configDir}
          ${asUser} /usr/bin/install -m 644 ${./karabiner.json} ${lib.escapeShellArg "${configDir}/karabiner.json"}
        '';
    };
}
