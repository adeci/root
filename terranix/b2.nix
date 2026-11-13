{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (self.inventory) b2;
  inherit (import ./lib.nix { inherit config lib self'; }) clanSecret safeName setClanVar;

  # Private and encrypted; hidden file versions go after a week.
  privateBucket = name: purpose: {
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
      inherit purpose;
      inherit (b2) region;
    };
  };

  # What a bucket's key may do with its files.
  bucketKeyCapabilities = [
    "listBuckets"
    "listFiles"
    "readFiles"
    "writeFiles"
    "deleteFiles"
    "readBucketEncryption"
  ];

  # Writes a key to a machine's clan var as an env file; terraform_data echoes its input unredacted, so only the key ID goes there.
  keyToClanVar =
    {
      keyName,
      machine,
      var,
      idVariable,
      secretVariable,
    }:
    let
      key = config.resource.b2_application_key.${keyName};
    in
    {
      input = {
        application_key_id = key "application_key_id";
      };
      triggers_replace = [ (key "application_key_id") ];

      provisioner.local-exec = {
        environment = {
          B2_APPLICATION_KEY_ID = key "application_key_id";
          B2_APPLICATION_KEY = "\${sensitive(b2_application_key.${keyName}.application_key)}";
        };
        command = ''
          set -eu
          printf '${idVariable}=%s\n${secretVariable}=%s\n' \
            "$B2_APPLICATION_KEY_ID" \
            "$B2_APPLICATION_KEY" \
            | ${setClanVar machine var}
        '';
      };
    };

  resticBucket = b2.buckets.resticBackups;
  resticInstance = self.clan.inventory.instances.restic or null;
  resticClients = if resticInstance == null then { } else resticInstance.roles.client.machines or { };
  resticKeyName = machine: "restic_${safeName machine}";
  # Inventory settings are modules; merge the role's and the machine's like clan does.
  resticClientSettings =
    machine:
    (lib.evalModules {
      modules = [
        { freeformType = lib.types.lazyAttrsOf lib.types.anything; }
        resticInstance.roles.client.settings
        resticClients.${machine}.settings
      ];
    }).config;

  ziplineBucket = b2.buckets.ziplineShares;
  ziplineMachine = ziplineBucket.credentials.machine;
  ziplineKeyName = "zipline_${safeName ziplineMachine}";
in
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

  resource.b2_bucket.restic_backups = privateBucket resticBucket.name "restic-backups";
  resource.b2_bucket.zipline_shares = privateBucket ziplineBucket.name "zipline-shares";

  resource.b2_application_key =
    lib.mapAttrs' (
      machine: _:
      lib.nameValuePair (resticKeyName machine) {
        key_name = "restic-${machine}";
        bucket_ids = [ (config.resource.b2_bucket.restic_backups "bucket_id") ];
        name_prefix = "${machine}/";
        capabilities = bucketKeyCapabilities;
      }
    ) resticClients
    // {
      ${ziplineKeyName} = {
        key_name = "zipline-${ziplineMachine}";
        bucket_ids = [ (config.resource.b2_bucket.zipline_shares "bucket_id") ];
        capabilities = bucketKeyCapabilities;
      };
    };

  resource.terraform_data =
    lib.mapAttrs' (
      machine: _:
      lib.nameValuePair "restic_b2_credentials_${safeName machine}" (keyToClanVar {
        keyName = resticKeyName machine;
        inherit machine;
        var = (resticClientSettings machine).credentials;
        idVariable = "AWS_ACCESS_KEY_ID";
        secretVariable = "AWS_SECRET_ACCESS_KEY";
      })
    ) resticClients
    // {
      "zipline_b2_credentials_${safeName ziplineMachine}" = keyToClanVar {
        keyName = ziplineKeyName;
        machine = ziplineMachine;
        var = ziplineBucket.credentials;
        idVariable = "DATASOURCE_S3_ACCESS_KEY_ID";
        secretVariable = "DATASOURCE_S3_SECRET_ACCESS_KEY";
      };
    };

  output.restic_b2_bucket = {
    value = resticBucket.name;
    description = "Backblaze B2 bucket for Restic backups.";
  };

  output.restic_b2_endpoint = {
    value = b2.s3Endpoint;
    description = "S3-compatible endpoint for Restic backups.";
  };

  output.zipline_b2_bucket = {
    value = ziplineBucket.name;
    description = "Private B2 bucket for Zipline file objects (not the metadata backup).";
  };
}
