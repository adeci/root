{
  config,
  pkgs,
  ...
}:
{
  services.vaultwarden = {
    enable = true;
    environmentFile = config.clan.core.vars.generators.vaultwarden.files."vaultwarden.env".path;
    config = {
      DOMAIN = "https://vault.decio.us";
      ROCKET_PORT = 8222;
      WEBSOCKET_ENABLED = true;
      WEBSOCKET_PORT = 3012;
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = true;
      SHOW_PASSWORD_HINT = false;
    };
  };

  clan.core.vars.generators.vaultwarden = {
    files.admin_token_plaintext = {
      secret = true;
      deploy = false;
    };
    files."vaultwarden.env" = { };

    runtimeInputs = with pkgs; [
      coreutils
      pwgen
      libargon2
    ];

    script = ''
      pwgen -s 48 1 | tr -d '\n' > "$out/admin_token_plaintext"

      SALT=$(pwgen -s 32 1 | tr -d '\n')
      HASHED=$(argon2 "$SALT" -e -id -k 65540 -t 3 -p 4 < "$out/admin_token_plaintext")

      echo "ADMIN_TOKEN='$HASHED'" > "$out/vaultwarden.env"
    '';
  };

  networking.firewall.allowedTCPPorts = [
    8222
    3012
  ];
}
