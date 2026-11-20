{
  darwin = {
    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
    };

    system.defaults.loginwindow.GuestEnabled = false;

    # Security responses install on their own; macOS versions only when chosen.
    system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
    # Full path: activation runs as root, and a bare domain hits root's own prefs.
    system.defaults.CustomSystemPreferences."/Library/Preferences/com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      AutomaticDownload = true;
      CriticalUpdateInstall = true;
      ConfigDataInstall = true;
    };
  };
}
