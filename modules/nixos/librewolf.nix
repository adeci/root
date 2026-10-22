# LibreWolf with policies and preferences baked in.
# No runtime file writes — everything is in the package.
{ pkgs, ... }:
let
  librewolf = pkgs.librewolf.override {
    extraPrefs = ''
      pref("identity.fxaccounts.enabled", true);
      pref("sidebar.revamp", true);
      pref("sidebar.verticalTabs", true);
      pref("privacy.resistFingerprinting", false);
      pref("webgl.disabled", false);
      pref("webgl.force-enabled", true);
      pref("librewolf.webgl.prompt", false);
      pref("media.ffmpeg.vaapi.enabled", true);
      pref("gfx.webrender.all", true);
      pref("layers.acceleration.force-enabled", true);
      pref("widget.dmabuf.force-enabled", true);
      pref("network.cookie.lifetimePolicy", 0);
      pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
      pref("privacy.clearOnShutdown.cookies", false);
      pref("privacy.clearOnShutdown.sessions", false);
    '';
  };
in
{
  environment.systemPackages = [ librewolf ];
}
