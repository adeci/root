{
  config,
  self,
  lib,
  safeName,
  setClanVar,
  privateBucket,
  bucketKeyCapabilities,
  ...
}:
let
  inherit (self.resources.b2.buckets.resticBackups) name;
  resticInstance = self.clan.inventory.instances.restic or null;
  clients = if resticInstance == null then { } else resticInstance.roles.client.machines or { };
  keyResourceName = machine: "restic_${safeName machine}";
  # Inventory settings are modules; merge the role's and the machine's like clan does.
  clientSettings =
    machine:
    (lib.evalModules {
      modules = [
        { freeformType = lib.types.lazyAttrsOf lib.types.anything; }
        resticInstance.roles.client.settings
        clients.${machine}.settings
      ];
    }).config;
  credentials = machine: (clientSettings machine).credentials;
in
{
  resource.b2_bucket.restic_backups = privateBucket name "restic-backups";

  resource.b2_application_key = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair (keyResourceName machine) {
      key_name = "restic-${machine}";
      bucket_ids = [ (config.resource.b2_bucket.restic_backups "bucket_id") ];
      name_prefix = "${machine}/";
      capabilities = bucketKeyCapabilities;
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
        # terraform_data echoes its input unredacted, so only the key ID goes there; the secret goes straight to the provisioner.
        environment = {
          B2_APPLICATION_KEY_ID = config.resource.b2_application_key.${resourceName} "application_key_id";
          B2_APPLICATION_KEY = "\${sensitive(b2_application_key.${resourceName}.application_key)}";
        };
        command = ''
          set -eu
          printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n' \
            "$B2_APPLICATION_KEY_ID" \
            "$B2_APPLICATION_KEY" \
            | ${setClanVar machine (credentials machine)}
        '';
      };
    }
  ) clients;

  output.restic_b2_bucket = {
    value = name;
    description = "Backblaze B2 bucket for Restic backups.";
  };

  output.restic_b2_endpoint = {
    value = self.resources.b2.s3Endpoint;
    description = "S3-compatible endpoint for Restic backups.";
  };
}
