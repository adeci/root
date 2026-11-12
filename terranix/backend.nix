{
  self,
  self',
  lib,
  ...
}:
let
  # A B2 account has one region, so the state bucket shares the managed buckets' endpoint.
  inherit (lib.head (lib.attrValues self.resources.b2.buckets)) region s3Endpoint;
in
{
  terraform.backend.s3 = {
    endpoints.s3 = "https://${s3Endpoint}";
    bucket = "adeci-terraform-state";
    key = "tofu.tfstate";
    inherit region;

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
