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

  # Defaults: the API at the device's homelan reservation, on RouterOS's API port.
  expandDevice =
    device:
    {
      host = homelan.hosts.${device.identity}.ip;
      port = 8728;
    }
    // device
    // (
      if device ? vlans && builtins.isList device.vlans then { vlans = vlanIdsFor device.vlans; } else { }
    );
in
builtins.mapAttrs (_: expandDevice) devices
