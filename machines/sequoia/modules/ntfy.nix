{ self, ... }:
let
  inherit (self.inventory.cloudflare.tunnels.sequoia.ntfy) host port;
in
{
  services.ntfy-sh.settings = {
    base-url = "https://${host}";
    listen-http = "127.0.0.1:${toString port}";
  };
}
