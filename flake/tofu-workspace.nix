# Scripts for one tofu workspace: each runs in .terraform/<workspace> with the
# generated config installed and the B2 state backend's credentials exported.
{
  pkgs,
  clan-cli,
  workspace,
  tfConfig,
}:
let
  setup = # bash
    ''
      cd "$(git rev-parse --show-toplevel)"
      mkdir -p .terraform/${workspace}
      cd .terraform/${workspace}

      AWS_ACCESS_KEY_ID=$(clan secrets get b2-key-id)
      AWS_SECRET_ACCESS_KEY=$(clan secrets get b2-application-key)
      AWS_REQUEST_CHECKSUM_CALCULATION=when_required
      AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
      export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
      export AWS_REQUEST_CHECKSUM_CALCULATION AWS_RESPONSE_CHECKSUM_VALIDATION

      install -m644 ${tfConfig} config.tf.json
    '';

  script =
    name: text:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.gitMinimal
        pkgs.opentofu
        clan-cli
      ];
      text = setup + "\n" + text;
    };
in
{
  inherit script;

  command =
    name: subcommand:
    script name ''
      tofu ${subcommand} "$@"
    '';
}
