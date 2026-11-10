# The same account as alex, with work keys and the work identity.
let
  email = "alex.decious@shopify.com";
in
import ./alex.nix
// {
  username = "alex";
  description = "Alex Shopify";
  inherit email;
  git = {
    name = "Alex Decious";
    inherit email;
  };
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClADO9vF1WDZmhaCDvvzq43FlbZ9n2y3+QHSs0pnwRq shopkey"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDuRxnCULDWByKpWGcVdrE4r/zgpkMQWV7OO28fYXogkGvyegbOEUhjgZF/tBtu31RQTGND7E2vBvYx68ncl5uY= delphi-tpm"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMu3Dg3Z7B1M788ypjewYGWoTCiJw34JeJKs570mg3W6XjHukb78j1DHijiJy8xbjrHyHqQtxJUrAEQMUVRFqfg= malum-se"
  ];
}
