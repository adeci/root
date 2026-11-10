# Restic backup bucket and per-machine credentials.
{
  config,
  self,
  inputs',
  lib,
  ...
}:
let
  bucket = self.resources.b2.buckets.resticBackups;
  inherit (bucket) name region s3Endpoint;
  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
  resticInstance = self.clan.inventory.instances.restic or null;
  clients = if resticInstance == null then { } else resticInstance.roles.client.machines or { };
  keyResourceName = machine: "restic_${safeName machine}";
  inherit (inputs'.clan-core.packages) clan-cli;
in
{
  resource.b2_bucket.restic_backups = {
    bucket_name = name;
    bucket_type = "allPrivate";

    default_server_side_encryption = [
      {
        mode = "SSE-B2";
        algorithm = "AES256";
      }
    ];

    lifecycle_rules = [
      {
        file_name_prefix = "";
        days_from_hiding_to_deleting = 7;
        days_from_starting_to_canceling_unfinished_large_files = 1;
      }
    ];

    bucket_info = {
      managed-by = "opentofu";
      purpose = "restic-backups";
      inherit region;
    };
  };

  resource.b2_application_key = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair (keyResourceName machine) {
      key_name = "restic-${machine}";
      bucket_ids = [ (config.resource.b2_bucket.restic_backups "bucket_id") ];
      name_prefix = "${machine}/";
      capabilities = [
        "listBuckets"
        "listFiles"
        "readFiles"
        "writeFiles"
        "deleteFiles"
        "readBucketEncryption"
      ];
    }
  ) clients;

  resource.terraform_data = lib.mapAttrs' (
    machine: _:
    let
      resourceName = keyResourceName machine;
    in
    lib.nameValuePair "restic_b2_credentials_${safeName machine}" {
      input = {
        application_key_id = config.resource.b2_application_key.${resourceName} "application_key_id";
      };
      triggers_replace = [ (config.resource.b2_application_key.${resourceName} "application_key_id") ];

      provisioner.local-exec = {
        # terraform_data echoes input into output without preserving sensitivity.
        # Keep only the key ID there; pass the secret directly to the provisioner.
        environment = {
          B2_APPLICATION_KEY_ID = config.resource.b2_application_key.${resourceName} "application_key_id";
          B2_APPLICATION_KEY = "\${sensitive(b2_application_key.${resourceName}.application_key)}";
        };
        command = ''
          set -eu
          printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n' \
            "$B2_APPLICATION_KEY_ID" \
            "$B2_APPLICATION_KEY" \
            | ${lib.getExe clan-cli} vars set ${machine} restic-b2-credentials/env
        '';
      };
    }
  ) clients;

  output.restic_b2_bucket = {
    value = name;
    description = "Backblaze B2 bucket for Restic backups.";
  };

  output.restic_b2_endpoint = {
    value = s3Endpoint;
    description = "S3-compatible endpoint for Restic backups.";
  };
}
