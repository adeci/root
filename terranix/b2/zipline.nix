{
  config,
  self,
  inputs',
  lib,
  safeName,
  ...
}:
let
  bucket = self.resources.b2.buckets.ziplineShares;
  inherit (bucket) credentials;
  inherit (credentials) machine;
  keyName = "zipline_${safeName machine}";
  key = config.resource.b2_application_key.${keyName};
  inherit (inputs'.clan-core.packages) clan-cli;
in
{
  resource.b2_bucket.zipline_shares = {
    bucket_name = bucket.name;
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
      purpose = "zipline-shares";
      inherit (bucket) region;
    };
  };

  resource.b2_application_key.${keyName} = {
    key_name = "zipline-${machine}";
    bucket_ids = [ (config.resource.b2_bucket.zipline_shares "bucket_id") ];
    capabilities = [
      "listBuckets"
      "listFiles"
      "readFiles"
      "writeFiles"
      "deleteFiles"
      "readBucketEncryption"
    ];
  };

  resource.terraform_data."zipline_b2_credentials_${safeName machine}" = {
    input = {
      application_key_id = key "application_key_id";
    };
    triggers_replace = [ (key "application_key_id") ];
    provisioner.local-exec = {
      # Never duplicate the secret into terraform_data's unredacted output.
      environment = {
        B2_APPLICATION_KEY_ID = key "application_key_id";
        B2_APPLICATION_KEY = "\${sensitive(b2_application_key.${keyName}.application_key)}";
      };
      command = ''
        set -eu
        printf 'DATASOURCE_S3_ACCESS_KEY_ID=%s\nDATASOURCE_S3_SECRET_ACCESS_KEY=%s\n' \
          "$B2_APPLICATION_KEY_ID" \
          "$B2_APPLICATION_KEY" \
          | ${lib.getExe clan-cli} vars set ${machine} ${credentials.generator}/${credentials.file}
      '';
    };
  };

  output.zipline_b2_bucket = {
    value = bucket.name;
    description = "Private B2 bucket for Zipline file objects (not the metadata backup).";
  };
}
