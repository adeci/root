{ pkgs, ... }:
{
  # Smart card daemon — required for age-plugin-yubikey and PKCS#11
  services.pcscd.enable = true;

  # Udev rules for YubiKey device recognition
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # Allow pcscd access from non-graphical sessions (SSH, TTY)
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.debian.pcsc-lite.access_pcsc" ||
          action.id == "org.debian.pcsc-lite.access_card") {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = with pkgs; [
    yubikey-manager # ykman — configure slots, PINs, FIDO, OTP
    yubikey-personalization # low-level YubiKey config + udev rules
    libfido2 # FIDO2/U2F tools (fido2-token, needed for ed25519-sk SSH keys)
    age-plugin-yubikey # age encryption/decryption via YubiKey PIV
  ];
}
