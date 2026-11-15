{ self, ... }:
let
  record = self.inventory.cloudflare.dns.ntfy_backup;
  domain = "${record.name}.${record.zone}";
in
{
  services.ntfy-sh = {
    settings.base-url = "https://${domain}";
    nginx = {
      enable = true;
      virtualHost = domain;
    };
  };

  services.nginx.virtualHosts.${domain}.enableACME = true;
}
