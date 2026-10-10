{
  description = "Alex Shopify";
  email = "alex.decious@shopify.com";
  uid = 3801;
  shell = "zsh";
  groups = [
    "wheel"
    "networkmanager"
    "video"
    "audio"
    "input"
    "kvm"
    "dialout"
  ];
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClADO9vF1WDZmhaCDvvzq43FlbZ9n2y3+QHSs0pnwRq shopkey"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDuRxnCULDWByKpWGcVdrE4r/zgpkMQWV7OO28fYXogkGvyegbOEUhjgZF/tBtu31RQTGND7E2vBvYx68ncl5uY= delphi-tpm"
  ];
}
