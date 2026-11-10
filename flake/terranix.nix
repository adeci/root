{
  inputs,
  lib,
  ...
}:
let
  # terranix/routeros is a separate workspace with its own state (routeros.nix).
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
    map (name: terranixDir + "/${name}") (builtins.attrNames (lib.filterAttrs isModule entries));

  machineDir = ../machines;
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
          # The decryption key is returned even without stored metadata: a
          # state written before the metadata existed still needs it.
          text = # bash
            ''
              echo '{"magic":"OpenTofu-External-Key-Provider","version":1}'
              cat >/dev/null || true
              PASSPHRASE=$(clan secrets get tf-passphrase)
              jq -n --arg key "$PASSPHRASE" '{"keys":{"encryption_key":($key|@base64),"decryption_key":($key|@base64)},"meta":{"external_data":{}}}'
            '';
        };
      }
      //
        lib.genAttrs
          [
            "tf-init"
            "tf-plan"
            "tf-apply"
            "tf-output"
            "tf-state"
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
