{
  # nix-darwin already has this option.
  nixos =
    { lib, ... }:
    {
      options.system.primaryUser = lib.mkOption {
        type = lib.types.str;
        description = "Name of the machine's main interactive user.";
      };
    };
}
