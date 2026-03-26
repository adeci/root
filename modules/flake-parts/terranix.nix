{
  inputs,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      self',
      inputs',
      ...
    }:
    let
      infraCloud = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = [
          ../terranix/base.nix
          ../../machines/conduit/terraform-configuration.nix
        ];
        extraArgs = {
          inherit self' inputs inputs';
        };
      };

      inherit (inputs'.clan-core.packages) clan-cli;

      # B2 backend auth — uses AWS env var names for S3 compatibility
      tfSetup = ''
        cd "$(git rev-parse --show-toplevel)"

        AWS_ACCESS_KEY_ID=$(clan secrets get b2-key-id)
        AWS_SECRET_ACCESS_KEY=$(clan secrets get b2-application-key)
        AWS_REQUEST_CHECKSUM_CALCULATION=when_required
        AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
        export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
        export AWS_REQUEST_CHECKSUM_CALCULATION AWS_RESPONSE_CHECKSUM_VALIDATION

        rm -f config.tf.json
        cp ${infraCloud} config.tf.json
      '';
    in
    {
      packages.get-clan-secret = pkgs.writeShellApplication {
        name = "get-clan-secret";
        runtimeInputs = [
          pkgs.jq
          clan-cli
        ];
        text = ''
          jq -n --arg secret "$(clan secrets get "$1")" '{"secret":$secret}'
        '';
      };

      packages.provide-tf-passphrase = pkgs.writeShellApplication {
        name = "opentofu-external-key-provider";
        runtimeInputs = [
          pkgs.jq
          clan-cli
        ];
        text = ''
          echo '{"magic":"OpenTofu-External-Key-Provider","version":1}'
          INPUT=$(cat) || true
          PASSPHRASE=$(clan secrets get tf-passphrase)
          if [[ "$INPUT" == "null" ]]; then
            jq -n --arg key "$PASSPHRASE" '{"keys":{"encryption_key":($key|@base64)}}'
          else
            jq -n --arg key "$PASSPHRASE" '{"keys":{"encryption_key":($key|@base64),"decryption_key":($key|@base64)}}'
          fi
        '';
      };

      packages.tf-init = pkgs.writeShellApplication {
        name = "tf-init";
        runtimeInputs = [
          pkgs.gitMinimal
          pkgs.opentofu
          clan-cli
        ];
        text = ''
          ${tfSetup}
          tofu init "$@"
        '';
      };

      packages.tf-plan = pkgs.writeShellApplication {
        name = "tf-plan";
        runtimeInputs = [
          pkgs.gitMinimal
          pkgs.opentofu
          clan-cli
        ];
        text = ''
          ${tfSetup}
          tofu plan "$@"
        '';
      };

      packages.tf-apply = pkgs.writeShellApplication {
        name = "tf-apply";
        runtimeInputs = [
          pkgs.gitMinimal
          pkgs.opentofu
          clan-cli
        ];
        text = ''
          ${tfSetup}
          tofu apply "$@"
        '';
      };

      packages.tf-destroy = pkgs.writeShellApplication {
        name = "tf-destroy";
        runtimeInputs = [
          pkgs.gitMinimal
          pkgs.opentofu
          clan-cli
        ];
        text = ''
          ${tfSetup}
          tofu destroy "$@"
        '';
      };
    };
}
