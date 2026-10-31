let
  hosts = import ./hosts.nix;
in
{
  # Private names, served by janus to the LAN and, through Tailscale split DNS,
  # to the tailnet. Atlas and mandate only listen on the tailnet, so they get
  # tailnet IPs.
  records = {
    "paperless.decio.us" = hosts.sequoia.ip;
    "atlas.decio.us" = "100.116.83.84";
    "mandate.decio.us" = "100.65.112.40";
  };
}
