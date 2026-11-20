{
  darwin =
    { pkgs, self, ... }:
    {
      imports = [ self.modules.darwin.mac-setup ];

      environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.scroll-reverser ];

      macSetup.steps = [
        {
          name = "Scroll Reverser";
          url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
          instructions = "Turn on Scroll Reverser.";
          grants = [
            {
              service = "kTCCServiceAccessibility";
              client = "com.pilotmoon.scroll-reverser";
            }
          ];
          restart = [ "gui/org.nixos.scroll-reverser" ];
        }
      ];

      system.defaults = {
        # Trackpad stays natural. Scroll Reverser flips only physical mouse wheels.
        NSGlobalDomain."com.apple.swipescrolldirection" = true;

        # Tracking speed slider at 8/10.
        ".GlobalPreferences"."com.apple.mouse.scaling" = 2.0;

        CustomUserPreferences = {
          "com.pilotmoon.scroll-reverser" = {
            HasRunBefore = true;
            InvertScrollingOn = true;
            ReverseMouse = true;
            ReverseTrackpad = false;
            ReverseX = false;
            ReverseY = true;
            ShowDiscreteScrollOptions = true;
            # Overrides Info.plist; the only way to silence Sparkle's update window.
            SUAutomaticallyUpdate = false;
            SUEnableAutomaticChecks = false;
          };
        };
      };

      launchd.user.agents.scroll-reverser.serviceConfig = {
        ProgramArguments = [ "/Applications/Nix Apps/Scroll Reverser.app/Contents/MacOS/Scroll Reverser" ];
        RunAtLoad = true;
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        LimitLoadToSessionType = "Aqua";
        ProcessType = "Interactive";
      };
    };
}
