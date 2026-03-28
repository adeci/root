# LibreWolf with policies, preferences, and browser-cli baked in.
# No runtime file writes — everything is in the package or /etc.
{
  pkgs,
  inputs,
  ...
}:
let
  micsSkills = inputs.mics-skills.packages.${pkgs.system};

  # Native messaging host for browser-cli extension
  browserCliNativeHost = pkgs.runCommand "browser-cli-native-host" { } ''
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    cat > $out/lib/mozilla/native-messaging-hosts/io.thalheim.browser_cli.bridge.json <<EOF
    {
      "name": "io.thalheim.browser_cli.bridge",
      "description": "Browser CLI bridge",
      "path": "${micsSkills.browser-cli}/bin/browser-cli-server",
      "type": "stdio",
      "allowed_extensions": ["browser-cli-controller@thalheim.io"]
    }
    EOF
  '';

  librewolf = pkgs.librewolf.override {
    extraPolicies = {
      ExtensionSettings = {
        "browser-cli-controller@thalheim.io" = {
          installation_mode = "force_installed";
          install_url = "file://${micsSkills.browser-cli-extension}/browser-cli-extension.xpi";
        };
      };
    };
    extraPrefs = ''
      pref("identity.fxaccounts.enabled", true);
      pref("xpinstall.signatures.required", false);
      pref("extensions.enabledScopes", 7);
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
    nativeMessagingHosts = [ browserCliNativeHost ];
  };
in
{
  environment.systemPackages = [ librewolf ];

  # browser-cli config — tells the CLI where to find LibreWolf
  environment.etc."xdg/browser-cli/config.toml".text = ''
    firefox_path = "${librewolf}/bin/librewolf"
  '';
}
