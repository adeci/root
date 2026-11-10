{
  config,
  self',
  lib,
  ...
}:
{
  terraform.required_providers.b2 = {
    source = "Backblaze/b2";
    version = "~> 0.12";
  };

  terraform.required_providers.external = {
    source = "registry.opentofu.org/hashicorp/external";
    version = "~> 2.0";
  };

  data.external.b2-admin-key-id = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "b2-admin-key-id"
    ];
  };

  data.external.b2-admin-application-key = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "b2-admin-application-key"
    ];
  };

  provider.b2 = {
    application_key_id = config.data.external.b2-admin-key-id "result.secret";
    application_key = config.data.external.b2-admin-application-key "result.secret";
  };
}
