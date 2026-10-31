let
  workMachines = import ../../../work/inventory/clan/machines.nix;
  addresses = import ./addresses.nix;
in
{
  inherit addresses;
  policy = import ./policy.nix { inherit addresses; };

  deviceTags = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = [ "tag:work" ];
      })
      (
        builtins.filter (name: builtins.elem "adeci-net-work" (workMachines.${name}.tags or [ ])) (
          builtins.attrNames workMachines
        )
      )
  );
}
