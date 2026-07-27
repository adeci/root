{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  micsSkills = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};

  browserCliManifest = pkgs.writeText "browser-cli-native-host.json" (
    builtins.toJSON {
      name = "io.thalheim.browser_cli.bridge";
      description = "Browser CLI bridge";
      path = "${micsSkills.browser-cli}/bin/browser-cli-server";
      type = "stdio";
      allowed_extensions = [ "browser-cli-controller@thalheim.io" ];
    }
  );

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
      pref("network.cookie.lifetimePolicy", 0);
      pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
      pref("privacy.clearOnShutdown.cookies", false);
      pref("privacy.clearOnShutdown.sessions", false);
    '';
  };

  librewolfBin = "/Applications/Nix Apps/LibreWolf.app/Contents/MacOS/librewolf";
in
{
  # browser-cli config — tells the CLI where to find LibreWolf
  environment.etc."xdg/browser-cli/config.toml".text = # toml
    ''
      firefox_path = "${librewolfBin}"
    '';

  # Install .app bundle for Dock/Spotlight
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

      for hostDir in \
        "/Users/${config.system.primaryUser}/Library/Application Support/Mozilla/NativeMessagingHosts" \
        "/Users/${config.system.primaryUser}/Library/Application Support/LibreWolf/NativeMessagingHosts"
      do
        install -d -o ${config.system.primaryUser} -g staff "$hostDir"
        install -m 0644 -o ${config.system.primaryUser} -g staff \
          ${browserCliManifest} "$hostDir/io.thalheim.browser_cli.bridge.json"
      done

      if [[ ! -f "$marker" ]] || [[ "$(cat "$marker")" != "$src" ]]; then
        echo "Syncing LibreWolf.app..."
        chmod -R u+w "$dest" 2>/dev/null || true
        rm -rf "$dest"
        /usr/bin/ditto "$app" "$dest"
        echo "$src" > "$marker"
      fi
    '';
}
