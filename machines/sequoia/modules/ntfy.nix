{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  domain = "ntfy.decio.us";
  inherit (self.inventory.cloudflare.tunnels.sequoia.${domain}) port;

  topics = {
    alerts = config.services.prometheus.alertmanager-ntfy.settings.ntfy.notification.topic;
  };

  subscribers = [
    {
      name = "alex";
      topics.${topics.alerts} = "ro";
    }
  ];

  publishers = [
    {
      name = "alertmanager";
      tokenLabel = "Alertmanager";
      topics.${topics.alerts} = "wo";
    }
  ];

  allUsers = subscribers ++ publishers;

  # Each user's generated values live in shell variables like alex_password.
  shellVariable =
    user: value: "${builtins.replaceStrings [ "-" "." ] [ "_" "_" ] user.name}_${value}";
  shellValue = user: value: "$" + shellVariable user value;

  generatePasswordAndHash = user: ''
    ${shellVariable user "password"}="$(openssl rand -base64 24 | tr -d '\n')"
    ${shellVariable user "hash"}="$(htpasswd -bnB -C 10 ${lib.escapeShellArg user.name} "${shellValue user "password"}" | cut -d: -f2-)"
  '';

  generateToken = publisher: ''
    ${shellVariable publisher "token"}="$(ntfy token generate | tr -d '\n')"
  '';

  subscriberPasswordFile = subscriber: "${subscriber.name}-password";

  writePasswordFile = subscriber: ''
    printf '%s\n' "${shellValue subscriber "password"}" > "$out/${subscriberPasswordFile subscriber}"
  '';

  accessEntries =
    user: lib.mapAttrsToList (topic: permission: "${user.name}:${topic}:${permission}") user.topics;
  authUsers = lib.concatMapStringsSep "," (
    user: "${user.name}:${shellValue user "hash"}:user"
  ) allUsers;
  authAccess = lib.concatStringsSep "," (lib.concatMap accessEntries allUsers);
  authTokens = lib.concatMapStringsSep "," (
    publisher: "${publisher.name}:${shellValue publisher "token"}:${publisher.tokenLabel}"
  ) publishers;

  subscriberPasswordFiles = lib.listToAttrs (
    map (
      subscriber: lib.nameValuePair (subscriberPasswordFile subscriber) { secret = true; }
    ) subscribers
  );
in
{
  clan.core.vars.generators.ntfy-alerts = {
    files = subscriberPasswordFiles // {
      # Running services keep the old credentials until they restart.
      "ntfy.env" = {
        secret = true;
        restartUnits = [ "ntfy-sh.service" ];
      };
      "alertmanager-ntfy.yml" = {
        secret = true;
        restartUnits = [ "alertmanager-ntfy.service" ];
      };
    };
    runtimeInputs = [
      pkgs.apacheHttpd
      pkgs.ntfy-sh
      pkgs.openssl
    ];
    script = # bash
      ''
        set -euo pipefail

        ${lib.concatMapStringsSep "\n" generatePasswordAndHash allUsers}
        ${lib.concatMapStringsSep "\n" generateToken publishers}

        ${lib.concatMapStringsSep "\n" writePasswordFile subscribers}

        {
          printf "NTFY_AUTH_USERS='%s'\n" "${authUsers}"
          printf "NTFY_AUTH_ACCESS='%s'\n" "${authAccess}"
          printf "NTFY_AUTH_TOKENS='%s'\n" "${authTokens}"
        } > "$out/ntfy.env"

        {
          printf 'ntfy:\n'
          printf '  auth:\n'
          printf '    token: "%s"\n' "$alertmanager_token"
        } > "$out/alertmanager-ntfy.yml"
      '';
  };

  clan.core.state.ntfy.folders = [
    "/var/lib/ntfy-sh"
  ];

  # Auth is provisioned from the generated EnvironmentFile so hashes/tokens never enter the Nix store.
  services.ntfy-sh = {
    enable = true;
    environmentFile = config.clan.core.vars.generators.ntfy-alerts.files."ntfy.env".path;
    settings = {
      base-url = "https://${domain}";
      listen-http = "127.0.0.1:${toString port}";
      behind-proxy = true;
      auth-default-access = "deny-all";
      enable-login = true;
      enable-signup = false;
      web-root = "disable";
    };
  };
}
