{
  inputs,
  lib,
  ...
}:
let
  # Auto-discover shared terranix modules
  terranixDir = ../terranix;
  terranixModules = map (name: terranixDir + "/${name}") (
    builtins.attrNames (
      lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
        builtins.readDir terranixDir
      )
    )
  );

  # Auto-discover per-machine terraform configs
  machineDir = ../../machines;
  machineTfConfigs = map (name: machineDir + "/${name}/terraform-configuration.nix") (
    builtins.filter (name: builtins.pathExists (machineDir + "/${name}/terraform-configuration.nix")) (
      builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir machineDir))
    )
  );
in
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
      tfConfig = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = terranixModules ++ machineTfConfigs;
        extraArgs = {
          inherit (inputs) self;
          inherit self' inputs inputs';
        };
      };

      inherit (inputs'.clan-core.packages) clan-cli;

      # B2 backend auth uses AWS env var names for S3 api
      tfSetup = # bash
        ''
          cd "$(git rev-parse --show-toplevel)"

          AWS_ACCESS_KEY_ID=$(clan secrets get b2-key-id)
          AWS_SECRET_ACCESS_KEY=$(clan secrets get b2-application-key)
          AWS_REQUEST_CHECKSUM_CALCULATION=when_required
          AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
          export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
          export AWS_REQUEST_CHECKSUM_CALCULATION AWS_RESPONSE_CHECKSUM_VALIDATION

          rm -f config.tf.json
          cp ${tfConfig} config.tf.json
        '';
    in
    {
      packages = {
        get-clan-secret = pkgs.writeShellApplication {
          name = "get-clan-secret";
          runtimeInputs = [
            pkgs.jq
            clan-cli
          ];
          text = ''
            jq -n --arg secret "$(clan secrets get "$1")" '{"secret":$secret}'
          '';
        };

        provide-tf-passphrase = pkgs.writeShellApplication {
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
      }
      //
        lib.genAttrs
          [
            "tf-init"
            "tf-plan"
            "tf-apply"
            "tf-destroy"
          ]
          (
            name:
            let
              cmd = lib.removePrefix "tf-" name;
            in
            pkgs.writeShellApplication {
              inherit name;
              runtimeInputs = [
                pkgs.gitMinimal
                pkgs.opentofu
                clan-cli
              ];
              text = ''
                ${tfSetup}
                tofu ${cmd} "$@"
              '';
            }
          );
    };
}
