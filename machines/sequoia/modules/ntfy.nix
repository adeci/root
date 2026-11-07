{
  config,
  lib,
  pkgs,
  ...
}:
let
  ntfyHost = "ntfy.decio.us";
  ntfyPort = 2586;

  topics = {
    atlas = "atlas-alerts";
  };

  # Add phone subscribers
  subscribers = [
    {
      name = "alex";
      topics.${topics.atlas} = "ro";
    }
  ];

  # Add publishing integrations
  publishers = [
    {
      name = "alertmanager";
      tokenLabel = "Alertmanager";
      topics.${topics.atlas} = "wo";
    }
  ];

  allUsers = subscribers ++ publishers;
  dollar = "$";
  safeShellName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;

  mkUserSetup =
    user:
    let
      var = safeShellName user.name;
    in
    ''
      ${var}_password="$(openssl rand -base64 24 | tr -d '\n')"
      ${var}_hash="$(htpasswd -bnB -C 10 ${lib.escapeShellArg user.name} "${dollar}${var}_password" | cut -d: -f2-)"
    '';

  mkPublisherToken =
    publisher:
    let
      var = safeShellName publisher.name;
    in
    ''
      ${var}_token="$(ntfy token generate | tr -d '\n')"
    '';

  subscriberPasswordFile = subscriber: "${subscriber.name}-password";

  mkSubscriberPasswordFile =
    subscriber:
    let
      var = safeShellName subscriber.name;
    in
    ''
      printf '%s\n' "${dollar}${var}_password" > "$out/${subscriberPasswordFile subscriber}"
    '';

  mkAccessEntries =
    user: lib.mapAttrsToList (topic: permission: "${user.name}:${topic}:${permission}") user.topics;
  authUsers = lib.concatMapStringsSep "," (
    user: "${user.name}:${dollar}${safeShellName user.name}_hash:user"
  ) allUsers;
  authAccess = lib.concatStringsSep "," (lib.concatMap mkAccessEntries allUsers);
  authTokens = lib.concatMapStringsSep "," (
    publisher:
    "${publisher.name}:${dollar}${safeShellName publisher.name}_token:${publisher.tokenLabel}"
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
      "ntfy.env".secret = true;
      "alertmanager-ntfy.yml".secret = true;
    };
    runtimeInputs = [
      pkgs.apacheHttpd
      pkgs.ntfy-sh
      pkgs.openssl
    ];
    script = # bash
      ''
        set -euo pipefail

        ${lib.concatMapStringsSep "\n" mkUserSetup allUsers}
        ${lib.concatMapStringsSep "\n" mkPublisherToken publishers}

        ${lib.concatMapStringsSep "\n" mkSubscriberPasswordFile subscribers}

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
      base-url = "https://${ntfyHost}";
      listen-http = "127.0.0.1:${toString ntfyPort}";
      behind-proxy = true;
      auth-default-access = "deny-all";
      enable-login = true;
      enable-signup = false;
      web-root = "disable";
    };
  };
}
