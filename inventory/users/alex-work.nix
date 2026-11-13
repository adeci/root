# alex's account with work keys and identity.
let
  alex = import ./alex.nix;
  email = "alex.decious@shopify.com";
in
alex
// {
  username = "alex";
  description = "Alex Shopify";
  inherit email;
  git = alex.git // {
    inherit email;
  };
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClADO9vF1WDZmhaCDvvzq43FlbZ9n2y3+QHSs0pnwRq shopkey"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDuRxnCULDWByKpWGcVdrE4r/zgpkMQWV7OO28fYXogkGvyegbOEUhjgZF/tBtu31RQTGND7E2vBvYx68ncl5uY= delphi-tpm"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMu3Dg3Z7B1M788ypjewYGWoTCiJw34JeJKs570mg3W6XjHukb78j1DHijiJy8xbjrHyHqQtxJUrAEQMUVRFqfg= malum-se"
  ];
}
