let
  workMachines = import ../../../work/inventory/clan/machines.nix;
in
{
  policy = ./policy.hujson;

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
