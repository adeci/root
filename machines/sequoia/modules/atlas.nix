{ lib, ... }:
let
  atlasHost = "atlas.decio.us";
  grafanaPort = 3000;
  tailnetCidr = "100.64.0.0/10";
in
{
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    80
    443
  ];

  services.grafana.settings.server = {
    domain = lib.mkForce atlasHost;
    root_url = lib.mkForce "https://${atlasHost}/";
    serve_from_sub_path = lib.mkForce false;
  };

  services.nginx.virtualHosts.${atlasHost} = {
    useACMEHost = "decio.us";
    forceSSL = true;

    extraConfig = ''
      allow 127.0.0.1;
      allow ${tailnetCidr};
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

  # Keep the monitoring ingest endpoints on the MagicDNS host, but move the UI
  # off plain HTTP.
  services.nginx.virtualHosts."sequoia.cymric-daggertooth.ts.net".locations = {
    "/grafana/" = lib.mkForce {
      return = "301 https://${atlasHost}/";
    };

    "= /" = lib.mkForce {
      return = "301 https://${atlasHost}/";
    };
  };
}
