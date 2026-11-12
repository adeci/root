let
  homelan = import ../homelan.nix;

  vlanIdsFor =
    vlanNames:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = homelan.vlans.${name}.id;
      }) vlanNames
    );

  # Defaults: identity from the device's name, the API at its LAN reservation on RouterOS's API port.
  expandDevice =
    name: device:
    {
      identity = name;
      host = device.lan.ip;
      port = 8728;
    }
    // device
    // (
      if device ? vlans && builtins.isList device.vlans then { vlans = vlanIdsFor device.vlans; } else { }
    );
in
{
  devices = builtins.mapAttrs expandDevice (import ./devices.nix);

  # Read-only API account for metrics scraping; its password lives in this machine's vars.
  exporter = {
    machine = "janus";
    generator = "routeros-exporter";
    file = "password";
    user = "prometheus";
  };
}
