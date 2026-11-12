let
  prefs = ''
    pref("identity.fxaccounts.enabled", true);
    pref("sidebar.revamp", true);
    pref("sidebar.verticalTabs", true);
    pref("privacy.resistFingerprinting", false);
    pref("webgl.disabled", false);
    pref("webgl.force-enabled", true);
    pref("librewolf.webgl.prompt", false);
    pref("network.cookie.lifetimePolicy", 0);
    pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
    pref("privacy.clearOnShutdown.cookies", false);
    pref("privacy.clearOnShutdown.sessions", false);
  '';
in
{
  nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.librewolf.override {
          extraPrefs = prefs + ''
            pref("media.ffmpeg.vaapi.enabled", true);
            pref("gfx.webrender.all", true);
            pref("layers.acceleration.force-enabled", true);
            pref("widget.dmabuf.force-enabled", true);
          '';
        })
      ];
    };

  darwin =
    {
      config,
      pkgs,
      self,
      ...
    }:
    let
      asUser = config.system.asPrimaryUser;
    in
    {
      imports = [
        self.modules.darwin.home-links
        self.modules.darwin.primary-user
      ];

      environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.librewolf-macos ];

      home.links.".librewolf/librewolf.overrides.cfg" = pkgs.writeText "librewolf.overrides.cfg" prefs;

      # macOS confirms a browser change in a dialog, so this only asks while LibreWolf isn't the default. The app is registered first: this runs before Launch Services has seen a freshly copied bundle.
      system.activationScripts.postActivation.text = ''
        ${asUser} /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
          -f "/Applications/Nix Apps/LibreWolf.app" || true
        ${asUser} /usr/bin/osascript -l JavaScript -e '
          ObjC.import("CoreServices");
          const id = "net.librewolf.librewolf";
          if (ObjC.castRefToObject($.LSCopyDefaultHandlerForURLScheme($("https"))).js !== id)
            $.LSSetDefaultHandlerForURLScheme($("http"), $(id));
        ' >/dev/null || true
      '';
    };
}
