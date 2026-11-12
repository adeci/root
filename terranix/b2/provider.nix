{ clanSecret, ... }:
{
  terraform.required_providers.b2 = {
    source = "Backblaze/b2";
    version = "~> 0.12";
  };

  clanSecrets = [
    "b2-admin-key-id"
    "b2-admin-application-key"
  ];

  provider.b2 = {
    application_key_id = clanSecret "b2-admin-key-id";
    application_key = clanSecret "b2-admin-application-key";
  };
}
