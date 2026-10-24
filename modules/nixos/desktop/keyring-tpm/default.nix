# Unlocks gnome-keyring at login with a TPM-sealed password; no PAM stack touches it.
{ lib, pkgs, ... }:
let
  unlock = pkgs.writeShellApplication {
    name = "keyring-tpm-unlock";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./unlock.sh;
  };

  setup = pkgs.writers.writePython3Bin "keyring-tpm-setup" {
    libraries = [ pkgs.python3Packages.pygobject3 ];
    doCheck = false;
  } (builtins.readFile ./setup.py);
in
{
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = lib.mkForce false;
  security.tpm2.enable = true;

  environment.systemPackages = [ setup ];

  systemd.user.services.keyring-tpm-unlock = {
    description = "gnome-keyring unlocked with a TPM-sealed password";
    partOf = [ "graphical-session.target" ];
    before = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    # Decrypt retry loops exhaust TPM sessions (ssh-tpm-agent too).
    startLimitIntervalSec = 120;
    startLimitBurst = 3;
    serviceConfig = {
      Type = "dbus";
      BusName = "org.freedesktop.secrets";
      ExecStart = lib.getExe unlock;
      Restart = "on-failure";
      RestartSec = 5;
      # 2: not set up yet; retrying can't help.
      RestartPreventExitStatus = 2;
    };
  };
}
