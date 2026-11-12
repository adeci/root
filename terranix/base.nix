{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (self.resources) b2;
in
{
  options.clanSecrets = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Clan secrets this workspace reads; read each with `clanSecret \"<name>\"`.";
  };

  config = {
    terraform.backend.s3 = {
      endpoints.s3 = "https://${b2.s3Endpoint}";
      bucket = b2.stateBucket;
      key = "tofu.tfstate";
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
        command = [ (lib.getExe self'.packages.provide-tf-passphrase) ];
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
        (lib.getExe self'.packages.get-clan-secret)
        secret
      ];
    });

    _module.args = {
      clanSecret = secret: config.data.external.${secret} "result.secret";

      # A command that stores its input in a machine's clan var.
      setClanVar =
        machine: var:
        "${lib.getExe self'.packages.clan-cli} vars set ${machine} ${var.generator}/${var.file}";

      # Hostnames, zones and machine names as Terraform resource names.
      safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
    };
  };
}
