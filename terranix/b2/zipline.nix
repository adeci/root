{
  config,
  self,
  safeName,
  setClanVar,
  privateBucket,
  bucketKeyCapabilities,
  ...
}:
let
  bucket = self.resources.b2.buckets.ziplineShares;
  inherit (bucket) credentials;
  inherit (credentials) machine;
  keyName = "zipline_${safeName machine}";
  key = config.resource.b2_application_key.${keyName};
in
{
  resource.b2_bucket.zipline_shares = privateBucket bucket.name "zipline-shares";

  resource.b2_application_key.${keyName} = {
    key_name = "zipline-${machine}";
    bucket_ids = [ (config.resource.b2_bucket.zipline_shares "bucket_id") ];
    capabilities = bucketKeyCapabilities;
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
          | ${setClanVar machine credentials}
      '';
    };
  };

  output.zipline_b2_bucket = {
    value = bucket.name;
    description = "Private B2 bucket for Zipline file objects (not the metadata backup).";
  };
}
