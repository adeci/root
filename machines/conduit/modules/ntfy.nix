{ self, ... }:
let
  inherit (self.inventory.cloudflare.dns.ntfy_backup) host;
in
{
  services.ntfy-sh = {
    settings.base-url = "https://${host}";
    nginx = {
      enable = true;
      virtualHost = host;
    };
  };

  services.nginx.virtualHosts.${host}.enableACME = true;
}
