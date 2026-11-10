{
  config,
  self,
  inputs',
  lib,
  ...
}:
let
  bucket = self.resources.b2.buckets.ziplineShares;
  key = config.resource.b2_application_key.zipline_conduit;
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

  resource.b2_application_key.zipline_conduit = {
    key_name = "zipline-conduit";
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

  # Like Restic, external provisioning writes only the service-scoped key into
  # encrypted Clan vars. B2 admin credentials never reach the service host.
  resource.terraform_data.zipline_b2_credentials_conduit = {
    input = {
      application_key_id = key "application_key_id";
    };
    triggers_replace = [ (key "application_key_id") ];
    provisioner.local-exec = {
      # Never duplicate the secret into terraform_data's unredacted output.
      environment = {
        B2_APPLICATION_KEY_ID = key "application_key_id";
        B2_APPLICATION_KEY = "\${sensitive(b2_application_key.zipline_conduit.application_key)}";
      };
      command = ''
        set -eu
        printf 'DATASOURCE_S3_ACCESS_KEY_ID=%s\nDATASOURCE_S3_SECRET_ACCESS_KEY=%s\n' \
          "$B2_APPLICATION_KEY_ID" \
          "$B2_APPLICATION_KEY" \
          | ${lib.getExe clan-cli} vars set conduit zipline-b2-credentials/env
      '';
    };
  };

  output.zipline_b2_bucket = {
    value = bucket.name;
    description = "Private B2 bucket for Zipline file objects (not the metadata backup).";
  };
}
