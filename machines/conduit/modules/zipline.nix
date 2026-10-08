{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  bucket = self.resources.b2.buckets.ziplineShares;
  port = 3002;
  origin = "share.decio.us";
  staging = "/var/cache/zipline";
in
{
  clan.core.postgresql.enable = true;
  clan.core.postgresql.users.zipline = { };
  clan.core.postgresql.databases.zipline = {
    create.options.OWNER = "zipline";
    restore.stopOnRestore = [ "zipline" ];
  };

  # Clan's PostgreSQL state declaration backs up the database, including users,
  # file metadata and settings. Objects live in B2; staging is not backup state.
  clan.core.vars.generators.zipline-secret = {
    files.env.secret = true;
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      printf 'CORE_SECRET=%s\n' "$(openssl rand -hex 64)" > "$out/env"
    '';
  };
  clan.core.vars.generators.zipline-b2-credentials.files.env = {
    secret = true;
    restartUnits = [ "zipline.service" ];
  };

  # Initial dashboard administrator only; ordinary user API tokens
  # are managed separately after signing in.
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
      config.clan.core.vars.generators.zipline-b2-credentials.files.env.path
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
      DATASOURCE_S3_REGION = bucket.region;
      DATASOURCE_S3_ENDPOINT = "https://${bucket.s3Endpoint}";
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
      # Zipline 4.8 serves raw files with CSP sandbox and nosniff, and limits
      # partial sessions to four per user with a 30-minute idle expiry.
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
    # Interrupted uploads are disposable. The cache is disk-backed, never /run
    # or tmpfs. Reserve >=12 GiB per uploader account for four <=2 GiB partial
    # sessions plus assembly. These app limits are not a filesystem quota.
    preStart = ''
      ${lib.getExe pkgs.findutils} ${staging} -mindepth 1 -delete
    '';
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    commonHttpConfig = ''
      limit_conn_zone $server_name zone=zipline_uploads:1m;
    '';
    virtualHosts.${origin} = {
      enableACME = true;
      forceSSL = true;
      # Slightly above the file limit to allow multipart headers.
      extraConfig = ''
        client_max_body_size 2049M;
        client_body_timeout 120s;
      '';
      locations = {
        # Only the local startup helper may create the initial administrator.
        # Public visitors must never be able to claim an uninitialized instance.
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
