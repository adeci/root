{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  micsSkills = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};
  chromeTabGc = pkgs.callPackage ../../pkgs/chrome-tab-gc-extension { };
  policies = import ../../pkgs/librewolf-policies.nix {
    inherit (micsSkills) browser-cli-extension;
    chrome-tab-gc-extension = chromeTabGc;
  };
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
    defaultPref("identity.fxaccounts.enabled", true);
    defaultPref("xpinstall.signatures.required", false);
    // Enable user scope for sideloaded extensions (1=profile, 2=user, 4=app)
    defaultPref("extensions.enabledScopes", 7);
    // Enable vertical tabs
    defaultPref("sidebar.revamp", true);
    defaultPref("sidebar.verticalTabs", true);
    // DNS over HTTPS via Quad9 — encrypts DNS lookups so your ISP can't see
    // them, and Quad9 blocks known malware domains. Mode 2 = try DoH first,
    // fall back to system DNS if it fails.
    // defaultPref("network.trr.mode", 2);
    // defaultPref("network.trr.uri", "https://dns.quad9.net/dns-query");
    // defaultPref("network.trr.bootstrapAddress", "9.9.9.9");
    // Resist Fingerprinting — LibreWolf spoofs screen size, timezone, fonts
    // etc. to prevent tracking. Disabling it fixes video conferencing apps
    // (Meet, Zoom) not being able to enumerate audio devices, and exempted
    // domains don't work reliably enough to maintain.
    defaultPref("privacy.resistFingerprinting", false);
  '';

  # Set LibreWolf as default browser
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "librewolf.desktop";
      "x-scheme-handler/http" = "librewolf.desktop";
      "x-scheme-handler/https" = "librewolf.desktop";
      "x-scheme-handler/about" = "librewolf.desktop";
      "x-scheme-handler/unknown" = "librewolf.desktop";
      "application/xhtml+xml" = "librewolf.desktop";
    };
  };

  # Register native messaging host for browser-cli
  home.activation.installBrowserCliHost = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${micsSkills.browser-cli}/bin/browser-cli --install-host
  '';
}
