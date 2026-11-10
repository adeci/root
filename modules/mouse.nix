{
  darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.scroll-reverser ];

      system.defaults = {
        # Trackpad stays natural. Scroll Reverser flips only physical mouse wheels.
        NSGlobalDomain."com.apple.swipescrolldirection" = true;

        # 2.0 is what macOS wrote when the Mouse tracking speed slider was set to
        # 8/10 in System Settings on malum.
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
            # Sparkle reads these over the app's Info.plist. The app never asks
            # for permission to check, so these alone silence the update window.
            SUAutomaticallyUpdate = false;
            SUEnableAutomaticChecks = false;
          };
        };
      };

      launchd.user.agents.scroll-reverser.serviceConfig = {
        Label = "org.nixos.scroll-reverser";
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
