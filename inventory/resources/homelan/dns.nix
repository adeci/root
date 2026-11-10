let
  hosts = import ./hosts.nix;
  tailnet = import ../tailscale/addresses.nix;
in
{
  # Served by janus to the LAN and, through Tailscale split DNS, to the
  # tailnet. Atlas and mandate only listen on the tailnet.
  records = {
    "paperless.decio.us" = hosts.sequoia.ip;
    "atlas.decio.us" = tailnet.sequoia;
    "mandate.decio.us" = tailnet.lachesis;
  };
}
