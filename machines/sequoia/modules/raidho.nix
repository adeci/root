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
  stateDir = "/var/lib/raidho";
  backupDir = "/var/backup/raidho";
  systemctl = lib.getExe' config.systemd.package "systemctl";

  preBackup = pkgs.writeShellApplication {
    name = "raidho-pre-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sqlite
      pkgs.util-linux
    ];
    runtimeEnv = {
      STATE_DIR = stateDir;
      BACKUP_DIR = backupDir;
    };
    text = ''
      umask 0077
      install -d -m 0700 -o raidho -g raidho "$BACKUP_DIR"

      if [ ! -f "$STATE_DIR/router.db" ]; then
        echo "No raidho database at $STATE_DIR/router.db, skipping backup snapshot"
        exit 0
      fi

      tmp=$(mktemp -p "$BACKUP_DIR" router.db.tmp.XXXXXX)
      trap 'rm -f "$tmp" "$tmp-wal" "$tmp-shm"' EXIT
      chown raidho:raidho "$tmp"

      # Run .backup as the raidho service user so root never opens the live WAL DB.
      runuser -u raidho -- sqlite3 -cmd ".timeout 30000" "$STATE_DIR/router.db" ".backup '$tmp'"

      # Scrub OAuth tokens and authenticated static upstream keys, then VACUUM to
      # wipe freed pages and leave a single self-contained DELETE-mode file.
      sqlite3 "$tmp" <<'SQL'
      PRAGMA journal_mode = DELETE;
      UPDATE accounts
         SET access_token = ''',
             refresh_token = ''',
             expires_at = 0,
             status = CASE WHEN status = 'active' THEN 'auth_error' ELSE status END;
      DELETE FROM static_upstreams WHERE auth != 'none';
      DELETE FROM models
       WHERE upstream NOT IN ('claude', 'codex', 'grok')
         AND upstream NOT IN (SELECT name FROM static_upstreams);
      VACUUM;
      SQL

      chmod 0600 "$tmp"
      chown root:root "$tmp"
      mv -f "$tmp" "$BACKUP_DIR/router.db"
    '';
  };

  postRestore = pkgs.writeShellApplication {
    name = "raidho-post-restore";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv = {
      STATE_DIR = stateDir;
      BACKUP_DIR = backupDir;
    };
    text = ''
      umask 0077
      if [ ! -f "$BACKUP_DIR/router.db" ]; then
        echo "No raidho backup at $BACKUP_DIR/router.db" >&2
        exit 1
      fi
      install -d -m 0700 -o raidho -g raidho "$STATE_DIR"
      rm -f "$STATE_DIR/router.db-wal" "$STATE_DIR/router.db-shm"
      install -m 0600 -o raidho -g raidho "$BACKUP_DIR/router.db" "$STATE_DIR/router.db"
    '';
  };
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
    preBackupScript = lib.getExe preBackup;
    preRestoreScript = ''
      ${systemctl} stop raidho.service
    '';
    postRestoreScript = ''
      ${lib.getExe postRestore}
      ${systemctl} start raidho.service
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
