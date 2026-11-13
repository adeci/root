{
  darwin =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      kitty = "${config.wrappers.kitty.wrapper}/bin/kitty";

      kitty-home = pkgs.writeShellScript "kitty-home" ''exec ${kitty} -d "$HOME"'';

      kitty-here = pkgs.writeShellApplication {
        name = "kitty-here";
        runtimeEnv.KITTY = kitty;
        text = builtins.readFile ./kitty-here.sh;
      };

      close-here = pkgs.writeShellApplication {
        name = "close-here";
        runtimeInputs = [ pkgs.aerospace ];
        text = builtins.readFile ./close-here.sh;
      };

      aerospaceConfig = pkgs.writeText "aerospace.toml" (
        builtins.replaceStrings
          [ "@KITTY_HOME@" "@KITTY_HERE@" "@CLOSE_HERE@" ]
          [ (toString kitty-home) (lib.getExe kitty-here) (lib.getExe close-here) ]
          (builtins.readFile ./config.toml)
      );

    in
    {
      imports = [
        self.modules.darwin.wrappers
        self.modules.darwin.mac-setup
        self.modules.darwin.code-signing
      ];

      codeSigning.binaries.borders = {
        source = "${self.packages.${pkgs.stdenv.hostPlatform.system}.jankyborders}/bin/borders";
        identifier = "git.felix.borders";
      };

      macSetup.steps = [
        {
          name = "AeroSpace and borders";
          url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
          instructions = "Turn on AeroSpace and borders.";
          grants = [
            {
              service = "kTCCServiceAccessibility";
              client = "bobko.aerospace";
            }
            {
              service = "kTCCServiceAccessibility";
              client = config.codeSigning.binaries.borders.path;
            }
          ];
          restart = [
            "gui/org.nixos.aerospace"
            "gui/org.nixos.jankyborders"
          ];
        }
      ];

      wrappers.kitty.enable = true;
      fonts.packages = [ pkgs.nerd-fonts.caskaydia-mono ];

      environment.systemPackages = [ pkgs.aerospace ];

      # macOS grants Accessibility to the process launchd spawns; the config's store path here restarts it on change.
      launchd.user.agents.aerospace.serviceConfig = {
        ProgramArguments = [
          "/Applications/Nix Apps/AeroSpace.app/Contents/MacOS/AeroSpace"
          "--config-path"
          "${aerospaceConfig}"
        ];
        RunAtLoad = true;
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        LimitLoadToSessionType = "Aqua";
        ProcessType = "Interactive";
      };

      services.jankyborders = {
        enable = true;
        inherit (config.codeSigning.binaries.borders) package;
        active_color = "0xff00C0A3";
        inactive_color = "0xff292e42";
        width = 2.0;
        hidpi = true;
        style = "round";
        # Below, the window's own drop shadow darkens the border's bottom and right edges.
        order = "above";
      };
    };
}
