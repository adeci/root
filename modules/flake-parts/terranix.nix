# Cloud infrastructure Terraform workspace (Cloudflare, Hetzner)
# RouterOS network workspace is in routeros.nix (separate state).
{
  inputs,
  lib,
  ...
}:
let
  # Auto-discover cloud terranix modules (excludes routeros — separate workspace)
  terranixDir = ../terranix;
  terranixModules =
    let
      entries = builtins.readDir terranixDir;
      isModule =
        name: type:
        (type == "regular" && lib.hasSuffix ".nix" name)
        || (
          type == "directory"
          && name != "routeros"
          && builtins.pathExists (terranixDir + "/${name}/default.nix")
        );
    in
    map (
      name:
      let
        type = entries.${name};
      in
      if type == "directory" then terranixDir + "/${name}" else terranixDir + "/${name}"
    ) (builtins.attrNames (lib.filterAttrs isModule entries));

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
          mkdir -p .terraform/cloud
          cd .terraform/cloud

          AWS_ACCESS_KEY_ID=$(clan secrets get b2-key-id)
          AWS_SECRET_ACCESS_KEY=$(clan secrets get b2-application-key)
          AWS_REQUEST_CHECKSUM_CALCULATION=when_required
          AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
          export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
          export AWS_REQUEST_CHECKSUM_CALCULATION AWS_RESPONSE_CHECKSUM_VALIDATION

          install -m644 ${tfConfig} config.tf.json
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
          text = # bash
            ''
              jq -n --arg secret "$(clan secrets get "$1")" '{"secret":$secret}'
            '';
        };

        provide-tf-passphrase = pkgs.writeShellApplication {
          name = "opentofu-external-key-provider";
          runtimeInputs = [
            pkgs.jq
            clan-cli
          ];
          text = # bash
            ''
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
              text = # bash
                ''
                  ${tfSetup}
                  tofu ${cmd} "$@"
                '';
            }
          );
    };
}
