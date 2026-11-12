{ self, ... }:
{
  imports = [
    ./provider.nix
    ./restic.nix
    ./zipline.nix
  ];

  _module.args = {
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
        inherit (self.resources.b2) region;
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
  };
}
