# Backblaze B2 service data; Terraform state bootstrap remains separate.
{
  imports = [
    ./provider.nix
    ./restic.nix
    ./zipline.nix
  ];
}
