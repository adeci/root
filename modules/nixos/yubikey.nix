# One-time setup per machine: plug in YubiKey, run ssh-keygen -K to download resident key handles to ~/.ssh/
{ pkgs, ... }:
{
  services.udev.packages = [ pkgs.yubikey-personalization ];
  environment.systemPackages = with pkgs; [
    yubikey-manager
    yubikey-personalization
    libfido2
  ];
}
