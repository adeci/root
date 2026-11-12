{
  self,
  self',
  lib,
  ...
}:
let
  inherit (self.resources) b2;
in
{
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
}
