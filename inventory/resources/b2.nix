{
  buckets = {
    resticBackups = {
      name = "adeci-restic-backups";
      region = "us-east-005";
      s3Endpoint = "s3.us-east-005.backblazeb2.com";
      # Clan var that terraform sets to each backup client's key.
      credentials = {
        generator = "restic-b2-credentials";
        file = "env";
      };
    };
    ziplineShares = {
      name = "adeci-shares";
      region = "us-east-005";
      s3Endpoint = "s3.us-east-005.backblazeb2.com";
      # Clan var that terraform sets to the bucket's key on the machine serving it.
      credentials = {
        machine = "conduit";
        generator = "zipline-b2-credentials";
        file = "env";
      };
    };
  };
}
