{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (self.inventory) appliances lan;
  inherit (self.inventory.routeros) models;
  inherit (import ../lib.nix { inherit config lib self'; }) safeName;

  switches = lib.filterAttrs (_: appliance: appliance.vlans != [ ]) appliances;

  # Every port but the management port, in the model's order.
  bridgePorts = switch: lib.remove switch.managementPort models.${switch.model}.ports;

  # Each VLAN of the switch with the bridge ports that carry it, tagged and untagged.
  vlanPorts =
    switch:
    lib.genAttrs switch.vlans (vlan: {
      tagged = lib.filter (port: lib.elem vlan switch.ports.${port}.carries.tagged) (bridgePorts switch);
      untagged = lib.filter (port: switch.ports.${port}.carries.untagged == vlan) (bridgePorts switch);
    });

  # A management port that tags VLANs stays out of the bridge, its IP on the untagged VLAN; each tagged VLAN joins the bridge through a sub-interface, so a single-cable switch configures in one apply.
  uplinkVlans = switch: switch.ports.${switch.managementPort}.carries.tagged;

  # A reference, not the plain name, so the sub-interface exists before the bridge entries that name it.
  uplink = name: vlan: config.resource.routeros_interface_vlan."${name}_uplink_${vlan}" "name";
in
{
  resource.routeros_interface_bridge = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    name = "bridge";
    vlan_filtering = true;
  }) switches;

  resource.routeros_interface_bridge_port = lib.concatMapAttrs (
    name: switch:
    lib.genAttrs' (bridgePorts switch) (
      portName:
      let
        port = switch.ports.${portName};
      in
      lib.nameValuePair "${name}_${safeName portName}" (
        {
          provider = "routeros.${name}";
          bridge = config.resource.routeros_interface_bridge.${name} "name";
          interface = portName;
          pvid = lan.vlans.${port.vlan}.id;
          frame_types =
            if port.carries.tagged == [ ] then "admit-only-untagged-and-priority-tagged" else "admit-all";
          ingress_filtering = true;
        }
        // lib.optionalAttrs (port.label != null) { comment = port.label; }
      )
    )
    // lib.genAttrs' (uplinkVlans switch) (
      vlan:
      lib.nameValuePair "${name}_uplink_${vlan}" {
        provider = "routeros.${name}";
        bridge = config.resource.routeros_interface_bridge.${name} "name";
        interface = uplink name vlan;
        pvid = lan.vlans.${vlan}.id;
        frame_types = "admit-only-untagged-and-priority-tagged";
        ingress_filtering = true;
      }
    )
  ) switches;

  resource.routeros_interface_vlan = lib.concatMapAttrs (
    name: switch:
    lib.genAttrs' (uplinkVlans switch) (
      vlan:
      lib.nameValuePair "${name}_uplink_${vlan}" {
        provider = "routeros.${name}";
        name = "${switch.managementPort}-v${toString lan.vlans.${vlan}.id}";
        interface = switch.managementPort;
        vlan_id = lan.vlans.${vlan}.id;
      }
    )
  ) switches;

  resource.routeros_interface_bridge_vlan = lib.concatMapAttrs (
    name: switch:
    lib.mapAttrs' (
      vlan: ports:
      lib.nameValuePair "${name}_${vlan}" {
        provider = "routeros.${name}";
        bridge = config.resource.routeros_interface_bridge.${name} "name";
        vlan_ids = [ lan.vlans.${vlan}.id ];
        tagged = [ "bridge" ] ++ ports.tagged;
        untagged = ports.untagged ++ lib.optional (lib.elem vlan (uplinkVlans switch)) (uplink name vlan);
      }
    ) (vlanPorts switch)
  ) switches;

  resource.routeros_interface_ethernet = lib.concatMapAttrs (
    name: switch:
    lib.mapAttrs' (
      portName: port:
      lib.nameValuePair "${name}_${safeName portName}" {
        provider = "routeros.${name}";
        factory_name = portName;
        name = portName;
        poe_out = port.poe;
      }
    ) (lib.filterAttrs (_: port: port.poe != null) switch.ports)
  ) switches;
}
