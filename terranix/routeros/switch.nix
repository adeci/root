{
  config,
  self,
  lib,
  safeName,
  deviceProvider,
  ...
}:
let
  inherit (self.resources.routeros) devices models;

  switches = lib.filterAttrs (_: d: d ? vlans) devices;

  modelPorts = device: models.${device.model}.ports;

  bridgePorts = device: lib.filter (p: p != device.managementPort) (modelPorts device);

  portCfg = device: port: device.ports.${port} or { };
  isTrunk = device: port: (portCfg device port).trunk or false;
  isHybrid = device: port: (portCfg device port).hybrid or false;
  portVlan = device: port: (portCfg device port).vlan or device.defaultVlan;
  portVlanId = device: port: device.vlans.${portVlan device port};
  portTaggedVlans = device: port: (portCfg device port).tagged or [ ];

  trunkPorts = device: lib.filter (isTrunk device) (bridgePorts device);
  hybridPorts = device: lib.filter (isHybrid device) (bridgePorts device);
  accessPorts = device: lib.filter (p: !isTrunk device p && !isHybrid device p) (bridgePorts device);
  accessPortsForVlan =
    device: vlanName: lib.filter (p: portVlan device p == vlanName) (accessPorts device);

  hybridPortsTaggedForVlan =
    device: vlanName:
    lib.filter (p: builtins.elem vlanName (portTaggedVlans device p)) (hybridPorts device);

  hybridPortsUntaggedForVlan =
    device: vlanName: lib.filter (p: portVlan device p == vlanName) (hybridPorts device);

  # A trunk managementPort stays standalone, its tagged VLANs bridged through sub-interfaces and its IP on untagged mgmt, so a single-cable switch configures in one apply.
  isMgmtTrunk = device: device.managementPort != null && isTrunk device device.managementPort;

  uplinkSubIf = port: vlanId: "${port}-v${toString vlanId}";

  nonMgmtVlans = device: lib.filterAttrs (n: _: n != "mgmt") device.vlans;

  # Resource references, not plain names, so the sub-interfaces exist before the bridge VLAN entries that name them.
  uplinkSubIfsForVlan =
    name: device: vlanName:
    if isMgmtTrunk device && vlanName != "mgmt" then
      [ (config.resource.routeros_interface_vlan."${name}_uplink_${vlanName}" "name") ]
    else
      [ ];

  switchesNeedingMgmtVlan = lib.filterAttrs (
    _: d: (d.managementPort == null || d ? fallbackPort) && !isMgmtTrunk d
  ) switches;
in
{
  resource.routeros_interface_bridge = lib.concatMapAttrs (name: _: {
    ${name} = {
      provider = deviceProvider name;
      name = "bridge";
      vlan_filtering = true;
    };
  }) switches;

  resource.routeros_interface_bridge_port = lib.concatMapAttrs (
    name: device:
    lib.listToAttrs (
      map (port: {
        name = "${name}_${safeName port}";
        value = {
          provider = deviceProvider name;
          bridge = config.resource.routeros_interface_bridge.${name} "name";
          interface = port;
          pvid = if isTrunk device port then device.vlans.${device.defaultVlan} else portVlanId device port;
          frame_types =
            if isTrunk device port || isHybrid device port then
              "admit-all"
            else
              "admit-only-untagged-and-priority-tagged";
          ingress_filtering = true;
        }
        // lib.optionalAttrs ((portCfg device port).comment or null != null) {
          inherit ((portCfg device port)) comment;
        };
      }) (bridgePorts device)
    )
    // lib.optionalAttrs (isMgmtTrunk device) (
      lib.mapAttrs' (
        vlanName: vlanId:
        lib.nameValuePair "${name}_uplink_${vlanName}" {
          provider = deviceProvider name;
          bridge = config.resource.routeros_interface_bridge.${name} "name";
          interface = config.resource.routeros_interface_vlan."${name}_uplink_${vlanName}" "name";
          pvid = vlanId;
          frame_types = "admit-only-untagged-and-priority-tagged";
          ingress_filtering = true;
        }
      ) (nonMgmtVlans device)
    )
  ) switches;

  resource.routeros_interface_ethernet = lib.concatMapAttrs (
    name: device:
    let
      portsWithPoe = lib.filter (p: (portCfg device p).poe or null != null) (modelPorts device);
    in
    lib.listToAttrs (
      map (port: {
        name = "${name}_${safeName port}";
        value = {
          provider = deviceProvider name;
          factory_name = port;
          name = port;
          poe_out = (portCfg device port).poe;
        };
      }) portsWithPoe
    )
  ) switches;

  resource.routeros_interface_vlan =
    lib.concatMapAttrs (
      name: device:
      lib.mapAttrs' (
        vlanName: vlanId:
        lib.nameValuePair "${name}_uplink_${vlanName}" {
          provider = deviceProvider name;
          name = uplinkSubIf device.managementPort vlanId;
          interface = device.managementPort;
          vlan_id = vlanId;
        }
      ) (nonMgmtVlans device)
    ) (lib.filterAttrs (_: isMgmtTrunk) switches)
    // lib.concatMapAttrs (name: device: {
      "${name}_mgmt" = {
        provider = deviceProvider name;
        name = "vlan${toString device.vlans.mgmt}";
        interface = config.resource.routeros_interface_bridge.${name} "name";
        vlan_id = device.vlans.mgmt;
      };
    }) switchesNeedingMgmtVlan;

  resource.routeros_ip_dhcp_client = lib.concatMapAttrs (name: _device: {
    "${name}_mgmt" = {
      provider = deviceProvider name;
      interface = config.resource.routeros_interface_vlan."${name}_mgmt" "name";
      comment = "Management VLAN — Managed by Terraform";
    };
  }) switchesNeedingMgmtVlan;

  resource.routeros_interface_bridge_vlan = lib.concatMapAttrs (
    name: device:
    lib.mapAttrs' (
      vlanName: vlanId:
      lib.nameValuePair "${name}_${vlanName}" {
        provider = deviceProvider name;
        bridge = config.resource.routeros_interface_bridge.${name} "name";
        vlan_ids = [ vlanId ];
        tagged = [ "bridge" ] ++ trunkPorts device ++ hybridPortsTaggedForVlan device vlanName;
        untagged =
          accessPortsForVlan device vlanName
          ++ hybridPortsUntaggedForVlan device vlanName
          ++ uplinkSubIfsForVlan name device vlanName;
      }
    ) device.vlans
  ) switches;
}
