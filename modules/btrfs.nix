{
  nixos =
    { config, lib, ... }:
    {
      services.btrfs.autoScrub = {
        enable = lib.any (fileSystem: fileSystem.fsType == "btrfs") (lib.attrValues config.fileSystems);
        interval = "weekly";
      };
    };
}
