let
  hosts = import ./hosts.nix;
in
{
  # Private names, served by janus to the LAN and, through Tailscale split DNS,
  # to the tailnet. Atlas only listens on the tailnet, so it gets the tailnet IP.
  records = {
    "paperless.decio.us" = hosts.sequoia.ip;
    "atlas.decio.us" = "100.116.83.84";
  };
}
