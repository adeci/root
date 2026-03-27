{
  wlib,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  micsSkills = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};

  policies = {
    ExtensionSettings = {
      "browser-cli-controller@thalheim.io" = {
        installation_mode = "force_installed";
        install_url = "file://${micsSkills.browser-cli-extension}/browser-cli-extension.xpi";
      };
    };
  };

  librewolfWithPolicies = pkgs.librewolf.override { extraPolicies = policies; };

  overridesCfg = pkgs.writeText "librewolf.overrides.cfg" ''
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

  librewolfBin =
    if isDarwin then
      "/Applications/Nix Apps/LibreWolf.app/Contents/MacOS/librewolf"
    else
      "${librewolfWithPolicies}/bin/librewolf";

  browserCliConfig = pkgs.writeText "browser-cli-config.toml" ''
    firefox_path = "${librewolfBin}"
  '';

  wrappedLibrewolf = pkgs.writeShellScriptBin "librewolf" (
    ''
      # Install overrides config
      PROFILE_DIR="$HOME/.librewolf"
      mkdir -p "$PROFILE_DIR"
      if [ ! -f "$PROFILE_DIR/librewolf.overrides.cfg" ] || \
         ! diff -q ${overridesCfg} "$PROFILE_DIR/librewolf.overrides.cfg" >/dev/null 2>&1; then
        cp ${overridesCfg} "$PROFILE_DIR/librewolf.overrides.cfg"
      fi

    ''
    + lib.optionalString isDarwin ''
      # Native messaging host (macOS path)
      NATIVE_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
    ''
    + lib.optionalString isLinux ''
      # Native messaging host (Linux path)
      NATIVE_DIR="$HOME/.librewolf/native-messaging-hosts"
    ''
    + ''

      mkdir -p "$NATIVE_DIR"
      if [ ! -f "$NATIVE_DIR/browser_cli.json" ]; then
        ${micsSkills.browser-cli}/bin/browser-cli --install-host 2>/dev/null || true
      fi

      # Install browser-cli config
      BROWSER_CLI_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/browser-cli"
      mkdir -p "$BROWSER_CLI_DIR"
      if [ ! -f "$BROWSER_CLI_DIR/config.toml" ] || \
         ! diff -q ${browserCliConfig} "$BROWSER_CLI_DIR/config.toml" >/dev/null 2>&1; then
        cp ${browserCliConfig} "$BROWSER_CLI_DIR/config.toml"
      fi

      exec ${librewolfBin} "$@"
    ''
  );
in
{
  imports = [ wlib.modules.default ];

  config.package = wrappedLibrewolf;
  config.passthru.librewolfWithPolicies = librewolfWithPolicies;
  config.meta.platforms = lib.platforms.linux ++ lib.platforms.darwin;
}
