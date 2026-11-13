{
  config,
  lib,
  self,
  ...
}:
let
  inherit (self.inventory) tailnet;

  domain = "atlas.decio.us";
  grafanaPort = config.services.grafana.settings.server.http_port;
in
{
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    80
    443
  ];

  services.grafana.settings.server = {
    domain = lib.mkForce domain;
    root_url = lib.mkForce "https://${domain}/";
    serve_from_sub_path = lib.mkForce false;
  };

  services.nginx.virtualHosts.${domain} = {
    useACMEHost = "decio.us";
    forceSSL = true;

    extraConfig = ''
      allow 127.0.0.1;
      allow ${tailnet.cidr};
      deny all;
      client_max_body_size 32m;
    '';

    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${toString grafanaPort}/";
        proxyWebsockets = true;
      };

      "= /grafana" = {
        return = "301 /";
      };

      "/grafana/" = {
        return = "301 /";
      };
    };
  };

  # Keep the monitoring ingest endpoints on the MagicDNS host, but move the UI off plain HTTP.
  services.nginx.virtualHosts.${config.networking.fqdn}.locations = {
    "/grafana/" = lib.mkForce {
      return = "301 https://${domain}/";
    };

    "= /" = lib.mkForce {
      return = "301 https://${domain}/";
    };
  };
}
