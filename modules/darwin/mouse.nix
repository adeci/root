# External mouse behavior for macOS.
# Keep the trackpad on natural scrolling, but make mouse wheels non-natural via
# Scroll Reverser. Also raises external mouse tracking speed.
{ config, lib, ... }:
let
  user = lib.escapeShellArg config.system.primaryUser;
  scrollReverserApp = "/Applications/Scroll Reverser.app";
  scrollReverserBin = "${scrollReverserApp}/Contents/MacOS/Scroll Reverser";
in
{
  homebrew.casks = [ "scroll-reverser" ];

  system.defaults = {
    # Trackpad stays natural. Scroll Reverser flips only physical mouse wheels.
    NSGlobalDomain."com.apple.swipescrolldirection" = true;

    # Mouse tracking speed. macOS stores this separately from trackpad speed.
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
      };
    };
  };

  launchd.user.agents.scroll-reverser.serviceConfig = {
    Label = "org.nixos.scroll-reverser";
    ProgramArguments = [ scrollReverserBin ];
    RunAtLoad = true;
    KeepAlive = {
      Crashed = true;
      SuccessfulExit = false;
    };
    LimitLoadToSessionType = "Aqua";
    ProcessType = "Interactive";
  };

  system.activationScripts.postActivation.text = # bash
    lib.mkAfter ''
      # Start Scroll Reverser now after activation; launchd handles future logins.
      if [[ -d ${lib.escapeShellArg scrollReverserApp} ]]; then
        launchctl asuser "$(/usr/bin/id -u -- ${user})" \
          sudo --user=${user} -- /usr/bin/open -gj -a "Scroll Reverser" || true
      fi
    '';
}
