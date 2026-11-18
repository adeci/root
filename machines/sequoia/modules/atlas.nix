{ config, self, ... }:
let
  inherit (self.inventory) tailnet;
in
{
  services.nginx.virtualHosts.${config.services.grafana.settings.server.domain} = {
    useACMEHost = "decio.us";
    forceSSL = true;

    extraConfig = ''
      allow 127.0.0.1;
      allow ${tailnet.cidr};
      deny all;
      client_max_body_size 32m;
    '';
  };
}
