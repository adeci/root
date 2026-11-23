{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (self.inventory) tailnet;
  inherit (self.inventory.lan.dns.raidho) host;
  cfg = config.services.raidho;
  vars = config.clan.core.vars.generators.raidho.files;
  backupDir = "/var/backup/raidho";
in
{
  imports = [ self.inputs.raidho.nixosModules.default ];

  services.raidho = {
    enable = true;
    hostname = host;
    environmentFile = vars."raidho.env".path;
  };

  clan.core.vars.generators.raidho = {
    files.admin-password.deploy = false;
    files.admin-token.deploy = false;
    files."raidho.env" = { };
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssl
      cfg.package
    ];
    script = ''
      openssl rand -base64 24 | tr -d '\n' > "$out/admin-password"
      printf 'raidho_admin_%s' "$(openssl rand -hex 32)" > "$out/admin-token"
      {
        printf 'RAIDHO_ADMIN_PASSWORD_HASH=%s\n' "$(raidho hash-password < "$out/admin-password")"
        printf 'RAIDHO_ADMIN_TOKEN_HASH=%s\n' "$(sha256sum < "$out/admin-token" | cut -d' ' -f1)"
      } > "$out/raidho.env"
    '';
  };

  clan.core.state.raidho = {
    folders = [ backupDir ];
    preBackupScript = ''
      install -d -m 0700 ${backupDir}
      ${lib.getExe pkgs.sqlite} /var/lib/private/raidho/router.db ".backup ${backupDir}/router.db"
    '';
  };

  services.nginx.virtualHosts.${host} = {
    useACMEHost = "decio.us";
    forceSSL = true;
    extraConfig = ''
      allow 127.0.0.1;
      allow ${tailnet.cidr};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://${cfg.listen}";
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
        client_max_body_size 64m;
      '';
    };
  };
}
