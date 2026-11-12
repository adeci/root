# Everything derived from the inventory, published as flake.resources.
{ lib, ... }:
let
  data = import ../inventory/inventory.nix;

  # A machine's reservation, plus one per extra interface (e.g. a BMC) named <machine>-<label>.
  machineHosts = lib.concatMapAttrs (
    name: machine:
    lib.optionalAttrs (machine ? lan) (
      {
        ${name} = builtins.removeAttrs machine.lan [ "extra" ];
      }
      // lib.mapAttrs' (
        label: extra: lib.nameValuePair "${name}-${label}" ({ inherit (machine.lan) vlan; } // extra)
      ) (machine.lan.extra or { })
    )
  ) data.machines;

  hosts =
    lib.mapAttrs (_: appliance: appliance.lan) data.appliances
    // lib.mapAttrs (_: vm: vm.lan) data.vms
    // machineHosts
    // lib.mapAttrs (_: device: device.lan) data.routeros.devices;

  addresses = lib.mapAttrs (_: machine: machine.tailnet) (
    lib.filterAttrs (_: machine: machine ? tailnet) data.machines
  );

  homelan = {
    inherit (data.lan) domain vlans;
    inherit hosts;
    dns.records = lib.mapAttrs (
      _: record: if record ? lan then hosts.${record.lan}.ip else addresses.${record.tailnet}
    ) data.lan.dns.records;
    inherit (data) router links;
  };

  # Defaults: identity from the device's name, the API at its LAN reservation on RouterOS's API port.
  expandDevice =
    name: device:
    {
      identity = name;
      host = device.lan.ip;
      port = 8728;
    }
    // device
    // lib.optionalAttrs (device ? vlans) {
      vlans = lib.genAttrs device.vlans (vlan: data.lan.vlans.${vlan}.id);
    }
    // lib.optionalAttrs (device ? wifi) {
      wifi = lib.genAttrs device.wifi (ssid: data.routeros.ssids.${ssid});
    };

  # A model's interface names: etherN, then sfp-sfpplusN.
  expandModel =
    model:
    model
    // {
      ports =
        builtins.genList (i: "ether${toString (i + 1)}") model.etherPorts
        ++ builtins.genList (i: "sfp-sfpplus${toString (i + 1)}") model.sfpPorts;
    };

  resources = {
    b2 = import ../inventory/b2.nix;
    cloudflare = import ../inventory/cloudflare.nix;
    inherit homelan;
    ingress = import ../inventory/ingress.nix;
    routeros = {
      devices = lib.mapAttrs expandDevice data.routeros.devices;
      models = lib.mapAttrs (_: expandModel) data.routeros.models;
      inherit (data.routeros) exporter;
    };
    tailscale = {
      inherit (data.tailnet) domain cidr deviceTags;
      inherit addresses;
      policy = import ../inventory/tailscale-policy.nix { inherit addresses homelan; };
    };
  };

  problems = import ./inventory-checks.nix {
    inherit lib data resources;
    instances = import ../inventory/instances.nix;
  };
in
{
  options.flake.resources = lib.mkOption { default = { }; };

  # Reading any resource fails while the inventory has problems, listing them all.
  config.flake.resources = lib.mapAttrs (
    _: resource:
    if problems == [ ] then
      resource
    else
      throw "The inventory has problems:\n${lib.concatMapStrings (problem: "  - ${problem}\n") problems}"
  ) resources;
}
