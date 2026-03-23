{
  lib,
  pkgs,
  inputs,

  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  micsSkills = inputs.mics-skills.packages.${system};
  policies = {
    ExtensionSettings = {
      "browser-cli-controller@thalheim.io" = {
        installation_mode = "force_installed";
        install_url = "file://${micsSkills.browser-cli-extension}/browser-cli-extension.xpi";
      };
    };
  };
  librewolfPath =
    if pkgs.stdenv.isDarwin then
      "/Applications/Nix Apps/LibreWolf.app/Contents/MacOS/librewolf"
    else
      "${pkgs.librewolf}/bin/librewolf";
in
{
  # Install LibreWolf on Linux (Darwin uses the darwin module)
  home.packages = lib.optionals pkgs.stdenv.isLinux [
    (pkgs.librewolf.override {
      extraPolicies = policies;
    })
  ];

  # Enable Firefox Account sync, unsigned extensions, vertical tabs, DoH
  home.file.".librewolf/librewolf.overrides.cfg".text = ''
    pref("identity.fxaccounts.enabled", true);
    pref("xpinstall.signatures.required", false);
    // Enable user scope for sideloaded extensions (1=profile, 2=user, 4=app)
    pref("extensions.enabledScopes", 7);
    // Enable vertical tabs
    pref("sidebar.revamp", true);
    pref("sidebar.verticalTabs", true);
    // DNS over HTTPS via Quad9 — encrypts DNS lookups so your ISP can't see
    // them, and Quad9 blocks known malware domains. Mode 2 = try DoH first,
    // fall back to system DNS if it fails.
    // pref("network.trr.mode", 2);
    // pref("network.trr.uri", "https://dns.quad9.net/dns-query");
    // pref("network.trr.bootstrapAddress", "9.9.9.9");
    // Resist Fingerprinting — LibreWolf spoofs screen size, timezone, fonts
    // etc. to prevent tracking. Disabling it fixes video conferencing apps
    // (Meet, Zoom) not being able to enumerate audio devices, and exempted
    // domains don't work reliably enough to maintain.
    pref("privacy.resistFingerprinting", false);
    // WebGL — LibreWolf disables it by default as a fingerprinting vector.
    // Needed for image editors, maps, and anything GPU-accelerated in-browser.
    pref("webgl.disabled", false);
    // Hardware acceleration — force-enable VA-API video decode and GPU compositing.
    pref("media.ffmpeg.vaapi.enabled", true);
    pref("gfx.webrender.all", true);
    // Keep cookies and storage across sessions — LibreWolf defaults to clearing
    // them on shutdown, which nukes all your logins every time you close the browser.
    // lifetimePolicy 2 (LibreWolf default) forces ALL cookies to be session-only,
    // so they die on close regardless of clearOnShutdown. Set to 0 for normal expiry.
    pref("network.cookie.lifetimePolicy", 0);
    pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
    // v1 equivalents — still checked in some LibreWolf versions
    pref("privacy.clearOnShutdown.cookies", false);
    pref("privacy.clearOnShutdown.sessions", false);
  '';

  # Tell browser-cli where LibreWolf is so browsh can find it
  xdg.configFile."browser-cli/config.toml".text = ''
    firefox_path = "${librewolfPath}"
  '';

  # Register native messaging host for browser-cli
  home.activation.installBrowserCliHost = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${micsSkills.browser-cli}/bin/browser-cli --install-host
  '';
}
