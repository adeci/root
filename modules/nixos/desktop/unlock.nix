# The login keyring's password must equal the LUKS passphrase.
{ pkgs, ... }:
{
  boot.plymouth.enable = true;
  # Caches the LUKS passphrase in the kernel keyring for pam_fde_boot_pw.
  boot.initrd.systemd.enable = true;

  security.pam.services.greetd.rules.session.fde-boot-pw = {
    order = 10000; # before `include login`, which opens gnome-keyring
    control = "optional";
    modulePath = "${pkgs.pam_fde_boot_pw}/lib/security/pam_fde_boot_pw.so";
    args = [ "inject_for=gkr" ];
  };
  # Lets greetd's session see that kernel keyring.
  systemd.services.greetd.serviceConfig.KeyringMode = "shared";
}
