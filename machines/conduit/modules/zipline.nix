{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (self.resources) b2;
  bucket = b2.buckets.ziplineShares;
  inherit (bucket) credentials;
  port = 3002;
  record = self.resources.cloudflare.dns.shares;
  origin = "${record.name}.${record.zone}";
  staging = "/var/cache/zipline";
in
{
  # Only the database (users, file metadata, settings) is backed up; objects live in B2.
  clan.core.postgresql.enable = true;
  clan.core.postgresql.users.zipline = { };
  clan.core.postgresql.databases.zipline = {
    create.options.OWNER = "zipline";
    restore.stopOnRestore = [ "zipline" ];
  };

  clan.core.vars.generators.zipline-secret = {
    files.env.secret = true;
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      printf 'CORE_SECRET=%s\n' "$(openssl rand -hex 64)" > "$out/env"
    '';
  };
  clan.core.vars.generators.${credentials.generator}.files.${credentials.file} = {
    secret = true;
    restartUnits = [ "zipline.service" ];
  };

  # Initial dashboard admin only; user API tokens are managed after signing in.
  clan.core.vars.generators.zipline-admin = {
    files."credentials.json".secret = true;
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      printf '{"username":"admin","password":"%s"}\n' \
        "$(openssl rand -hex 32)" > "$out/credentials.json"
    '';
  };

  services.zipline = {
    enable = true;
    package = self.packages.${pkgs.stdenv.hostPlatform.system}.zipline;
    database.createLocally = false;
    environmentFiles = [
      config.clan.core.vars.generators.zipline-secret.files.env.path
      config.clan.core.vars.generators.${credentials.generator}.files.${credentials.file}.path
    ];
    settings = {
      DATABASE_URL = "postgresql://zipline@localhost/zipline?host=/run/postgresql";
      CORE_HOSTNAME = "127.0.0.1";
      CORE_PORT = port;
      CORE_TEMP_DIRECTORY = staging;
      CORE_DEFAULT_DOMAIN = origin;
      CORE_RETURN_HTTPS_URLS = "true";
      CORE_TRUST_PROXY = "true";
      CORE_TRUSTED_PROXIES = "127.0.0.1,::1";
      DATASOURCE_TYPE = "s3";
      DATASOURCE_S3_BUCKET = bucket.name;
      DATASOURCE_S3_REGION = b2.region;
      DATASOURCE_S3_ENDPOINT = "https://${b2.s3Endpoint}";
      DATASOURCE_S3_FORCE_PATH_STYLE = "true";
      FEATURES_USER_REGISTRATION = "false";
      FEATURES_OAUTH_REGISTRATION = "false";
      INVITES_ENABLED = "false";
      FEATURES_ROBOTS_TXT = "true";
      FEATURES_HEALTHCHECK = "true";
      FEATURES_VERSION_CHECKING = "false";
      FEATURES_IMAGE_COMPRESSION = "false";
      FEATURES_THUMBNAILS_ENABLED = "false";
      FILES_ROUTE = "/u";
      FILES_DEFAULT_FORMAT = "random";
      FILES_LENGTH = 32;
      FILES_MAX_FILE_SIZE = "2gb";
      FILES_MAX_FILES_PER_UPLOAD = 1;
      FILES_ASSUME_MIMETYPES = "true";
      # Zipline 4.8 sandboxes raw files (CSP, nosniff) and caps users at four partial sessions with a 30-min idle expiry.
      CHUNKS_ENABLED = "true";
      CHUNKS_SIZE = "25mb";
      CHUNKS_MAX = "25mb";
    };
  };

  systemd.services.zipline = {
    after = [ "postgresql.target" ];
    requires = [ "postgresql.target" ];
    serviceConfig = {
      CacheDirectory = "zipline";
      MemoryHigh = "1G";
      MemoryMax = "1400M";
      LoadCredential = [
        "admin.json:${config.clan.core.vars.generators.zipline-admin.files."credentials.json".path}"
      ];
      ExecStartPost = [
        "${lib.getExe config.services.zipline.package.bootstrapAdmin} %d/admin.json"
      ];
      TimeoutStartSec = 120;
    };
    # Interrupted uploads are disposable; reserve >=12 GiB of disk (not tmpfs) per uploader, as app limits aren't a quota.
    preStart = ''
      ${lib.getExe pkgs.findutils} ${staging} -mindepth 1 -delete
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "alex@decio.us";
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    commonHttpConfig = ''
      limit_conn_zone $server_name zone=zipline_uploads:1m;
    '';
    virtualHosts.${origin} = {
      enableACME = true;
      forceSSL = true;
      extraConfig = ''
        # Slightly above the file limit to allow multipart headers.
        client_max_body_size 2049M;
        client_body_timeout 120s;
      '';
      locations = {
        # Only the local startup helper may create the first admin, so visitors can't claim a fresh instance.
        "= /api/setup".return = "403";
        "/api/upload" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
          extraConfig = ''
            # Zipline permits anonymous public-folder uploads. Reject that
            # exception, while retaining session-authenticated dashboard use.
            set $zipline_upload_auth "$http_authorization$cookie_zipline_session";
            if ($zipline_upload_auth = "") { return 401; }
            limit_conn zipline_uploads 1;
            limit_conn_status 429;
            proxy_request_buffering off;
            proxy_buffering off;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };
        "/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_read_timeout 3600s;
          '';
        };
      };
    };
  };
}
