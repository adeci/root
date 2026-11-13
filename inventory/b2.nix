let
  # One account, so every bucket shares it.
  region = "us-east-005";
in
{
  inherit region;
  s3Endpoint = "s3.${region}.backblazeb2.com";

  # Holds the Terraform state, so it is made by hand rather than managed with the others.
  stateBucket = "adeci-terraform-state";

  buckets = {
    resticBackups = {
      name = "adeci-restic-backups";
      # Clan var that terraform sets to each backup client's key.
      credentials = {
        generator = "restic-b2-credentials";
        file = "env";
      };
    };
    ziplineShares = {
      name = "adeci-shares";
      # Clan var that terraform sets to the bucket's key on the machine serving it.
      credentials = {
        machine = "conduit";
        generator = "zipline-b2-credentials";
        file = "env";
      };
    };
  };
}
