{ lib, ... }:
let
  inherit (lib) mkDefault;
  inherit (lib.types) attrsOf anything;
in
{
  _class = "clan.service";
  manifest = {
    name = "@onix/vaultwarden";
    description = "Vaultwarden password manager server for secure credential storage";
    categories = [ "Security" ];
    readme = builtins.readFile ./README.md;
  };

  roles = {
    server = {
      description = "Vaultwarden password manager server";
      interface = {
        # Freeform module - any attribute becomes a Vaultwarden environment variable
        freeformType = attrsOf anything;
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              localSettings = extendSettings {
                # Secure defaults - override in inventory if needed
                DOMAIN = mkDefault "https://vault.decio.us";
                ROCKET_PORT = mkDefault 8222;
                WEBSOCKET_ENABLED = mkDefault true;
                WEBSOCKET_PORT = mkDefault 3012;
                SIGNUPS_ALLOWED = mkDefault false;
                INVITATIONS_ALLOWED = mkDefault true;
                SHOW_PASSWORD_HINT = mkDefault false;
              };

              # All settings become Vaultwarden environment variables
              environment = localSettings;

              # Path to environment file with hashed admin token
              adminEnvFile =
                config.clan.core.vars.generators."vaultwarden-${instanceName}".files."vaultwarden.env".path;
            in
            {
              # Main Vaultwarden service
              services.vaultwarden = {
                enable = true;
                config = environment;
                environmentFile = adminEnvFile;
              };

              # Instance-specific admin token generator with Argon2 hashing
              clan.core.vars.generators."vaultwarden-${instanceName}" = {
                share = true; # Share token across machines in instance for consistent admin access

                files.admin_token_plaintext = {
                  secret = true; # Encrypt at rest
                  deploy = false; # Don't deploy to machines - only for admin reference
                };
                files."vaultwarden.env" = { }; # Contains hashed token, deployed to machines

                runtimeInputs = with pkgs; [
                  coreutils
                  pwgen
                  libargon2
                ];

                script = ''
                  # Generate a secure random admin token
                  pwgen -s 48 1 | tr -d '\n' > "$out/admin_token_plaintext"

                  # Hash with Argon2 (vaultwarden accepts Argon2 hashed tokens)
                  # This means even if the env file is compromised, attacker can't access admin
                  SALT=$(pwgen -s 32 1 | tr -d '\n')
                  HASHED=$(argon2 "$SALT" -e -id -k 65540 -t 3 -p 4 < "$out/admin_token_plaintext")

                  # Write environment file with the hashed token
                  echo "ADMIN_TOKEN='$HASHED'" > "$out/vaultwarden.env"
                '';
              };

              # Open firewall ports if configured
              networking.firewall.allowedTCPPorts =
                lib.optional (environment ? ROCKET_PORT) environment.ROCKET_PORT
                ++ lib.optional (environment ? WEBSOCKET_PORT) environment.WEBSOCKET_PORT;
            };
        };
    };
  };

}
