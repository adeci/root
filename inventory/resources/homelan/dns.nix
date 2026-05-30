let
  hosts = import ./hosts.nix;
in
{
  # Split-horizon DNS records served by janus.
  # Public DNS points these names at Tailnet targets; janus overrides them to
  # LAN IPs for local clients.
  records = {
    "paperless.decio.us" = hosts.sequoia.ip;
  };
}
