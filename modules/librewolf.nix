{
  nixos =
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
    };

  darwin =
    {
      lib,
      pkgs,
      ...
    }:
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
          pref("network.cookie.lifetimePolicy", 0);
          pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
          pref("privacy.clearOnShutdown.cookies", false);
          pref("privacy.clearOnShutdown.sessions", false);
        '';
      };
    in
    {
      system.activationScripts.postActivation.text = # bash
        lib.mkAfter ''
          echo "installing LibreWolf.app..."
          targetDir='/Applications/Nix Apps'
          markerDir="$targetDir/.sources"
          mkdir -p "$targetDir" "$markerDir"

          src="${librewolf}"
          app="$src/Applications/LibreWolf.app"
          dest="$targetDir/LibreWolf.app"
          marker="$markerDir/LibreWolf.app"

          if [[ ! -f "$marker" ]] || [[ "$(cat "$marker")" != "$src" ]]; then
            echo "Syncing LibreWolf.app..."
            chmod -R u+w "$dest" 2>/dev/null || true
            rm -rf "$dest"
            /usr/bin/ditto "$app" "$dest"
            echo "$src" > "$marker"
          fi
        '';
    };
}
