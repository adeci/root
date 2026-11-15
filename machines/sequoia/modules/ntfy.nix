{ self, ... }:
let
  domain = "ntfy.decio.us";
  inherit (self.inventory.cloudflare.tunnels.sequoia.${domain}) port;
in
{
  services.ntfy-sh.settings = {
    base-url = "https://${domain}";
    listen-http = "127.0.0.1:${toString port}";
  };
}
