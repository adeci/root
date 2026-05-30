{
  config,
  pkgs,
  self,
  ...
}:
let
  inherit (self.resources) homelan;
  paperlessDns = self.resources.cloudflare.dns.paperless;

  paperlessHost = "${paperlessDns.name}.${paperlessDns.zone}";
  tailnetCidr = "100.64.0.0/10";

  dataDir = "/srv/paperless";
in
{
  # Paperless-ngx document archive.

  clan.core.state.paperless.folders = [ dataDir ];

  clan.core.vars.generators.paperless = {
    files = {
      admin-password.secret = true;
    };

    runtimeInputs = [ pkgs.pwgen ];

    script = ''
      pwgen -s 32 1 | tr -d '\n' > "$out/admin-password"
    '';
  };

  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    port = 28981;
    domain = paperlessHost;
    configureNginx = true;

    inherit dataDir;

    passwordFile = config.clan.core.vars.generators.paperless.files.admin-password.path;
    database.createLocally = true;

    exporter.enable = true;

    settings = {
      PAPERLESS_ADMIN_USER = "alex";
      PAPERLESS_OCR_ROTATE_PAGES = true;
      PAPERLESS_CONSUMER_RECURSIVE = true;
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    serverTokens = false;

    virtualHosts.${paperlessHost} = {
      useACMEHost = paperlessDns.zone;
      extraConfig = ''
        allow ${homelan.vlans.trusted.cidr};
        allow ${tailnetCidr};
        deny all;
        client_max_body_size 512M;
      '';
    };
  };
}
