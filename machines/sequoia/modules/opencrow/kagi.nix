{
  config,
  inputs,
  pkgs,
  ...
}:
let
  micsSkillsPkgs = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  # Kagi search needs a session token. The kagi-search CLI reads it via
  # `rbw get kagi-session-link` by default. We use the same mock-rbw
  # pattern as Mic92: a wrapper script that reads from systemd credentials.

  clan.core.vars.generators.opencrow-kagi = {
    files.kagi-session-token.secret = true;
    prompts.kagi-session-token = {
      description = "Kagi session token for OpenCrow (from kagi.com account settings)";
      type = "hidden";
      persist = true;
    };
    script = ''
      cp "$prompts/kagi-session-token" "$out/kagi-session-token"
    '';
  };

  services.opencrow.credentialFiles."kagi-session-token" =
    config.clan.core.vars.generators.opencrow-kagi.files.kagi-session-token.path;

  services.opencrow.extraPackages = [
    micsSkillsPkgs.kagi-search

    # Mock rbw that returns credentials from systemd's credential store.
    # kagi-search calls `rbw get kagi-session-link` to retrieve the token.
    (pkgs.writeShellScriptBin "rbw" ''
      case "$1 $2" in
        "get kagi-session-link")
          cat "/run/credentials/opencrow.service/kagi-session-token"
          ;;
        *)
          echo "rbw mock: unknown entry '$2'" >&2
          exit 1
          ;;
      esac
    '')
  ];

  containers.opencrow.config.systemd.tmpfiles.rules = [
    "d /var/lib/opencrow/.config/kagi 0750 opencrow opencrow -"
    ''f /var/lib/opencrow/.config/kagi/config.json 0640 opencrow opencrow - {"password_command":"rbw get kagi-session-link"}''
  ];
}
