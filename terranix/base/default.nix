{
  config,
  lib,
  pkgs,
  self,
  self',
  ...
}:
let
  inherit (self.inventory) b2;
  inherit (self'.packages) clan-cli;

  getClanSecret = pkgs.writeShellApplication {
    name = "get-clan-secret";
    runtimeInputs = [
      pkgs.jq
      clan-cli
    ];
    text = builtins.readFile ./get-clan-secret.sh;
  };

  passphraseProvider = pkgs.writeShellApplication {
    name = "opentofu-external-key-provider";
    runtimeInputs = [
      pkgs.jq
      clan-cli
    ];
    text = builtins.readFile ./opentofu-external-key-provider.sh;
  };
in
{
  options.clanSecrets = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Clan secrets this workspace reads; read each with `clanSecret \"<name>\"` from ../lib.nix.";
  };

  config = {
    # The workspace builder sets the state's key.
    terraform.backend.s3 = {
      endpoints.s3 = "https://${b2.s3Endpoint}";
      bucket = b2.stateBucket;
      inherit (b2) region;

      # B2 isn't *real* S3 so skip AWS-specific checks
      skip_credentials_validation = true;
      skip_region_validation = true;
      skip_metadata_api_check = true;
      skip_requesting_account_id = true;
      skip_s3_checksum = true;
    };

    terraform.encryption = {
      key_provider.external.passphrase = {
        command = [ (lib.getExe passphraseProvider) ];
      };
      key_provider.pbkdf2.state_encryption_password = {
        chain = lib.tf.ref "key_provider.external.passphrase";
      };
      method.aes_gcm.encryption_method.keys = lib.tf.ref "key_provider.pbkdf2.state_encryption_password";

      state.enforced = true;
      state.method = "method.aes_gcm.encryption_method";
      plan.enforced = true;
      plan.method = "method.aes_gcm.encryption_method";
    };

    terraform.required_providers.external = {
      source = "registry.opentofu.org/hashicorp/external";
      version = "~> 2.0";
    };

    data.external = lib.genAttrs config.clanSecrets (secret: {
      program = [
        (lib.getExe getClanSecret)
        secret
      ];
    });
  };
}
