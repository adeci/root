let
  homelan = import ../homelan;

  devices = {
    nexus = import ./nexus.nix;
    axon = import ./axon.nix;
    zephyr = import ./zephyr.nix;
    nimbus = import ./nimbus.nix;
  };

  vlanIdsFor =
    vlanNames:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = homelan.vlans.${name}.id;
      }) vlanNames
    );

  expandDevice =
    device:
    device
    // (
      if device ? vlans && builtins.isList device.vlans then { vlans = vlanIdsFor device.vlans; } else { }
    );
in
builtins.mapAttrs (_: expandDevice) devices
