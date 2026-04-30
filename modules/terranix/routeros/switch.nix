# RouterOS switch resources — bridge, ports, VLANs
# Applied to devices that have a `vlans` attribute in their data.
#
# Standalone trunk management: when managementPort is a trunk port, it stays
# standalone (like WAP ether1) with VLAN sub-interfaces feeding tagged traffic
# into the bridge. Management IP comes from untagged mgmt on the hybrid uplink.
# This allows single-cable switches to be configured in one terraform apply.
{
  config,
  self,
  lib,
  ...
}:
let
  inherit (self.resources) routeros;

  # Only devices with vlans (switches, not WAPs)
  switches = lib.filterAttrs (_: d: d ? vlans) routeros;

  deviceProvider = name: "routeros.${name}";
  safeName = builtins.replaceStrings [ "-" ] [ "_" ];

  # Port names generated from model spec
  models = import ./models.nix;
  portsForModel =
    model:
    let
      spec = models.${model};
    in
    (builtins.genList (i: "ether${toString (i + 1)}") spec.etherPorts)
    ++ (builtins.genList (i: "sfp-sfpplus${toString (i + 1)}") spec.sfpPorts);

  # ── Per-device helpers ───────────────────────────────────────────
  bridgePorts = device: lib.filter (p: p != device.managementPort) (portsForModel device.model);

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

  # Hybrid ports that carry a given VLAN as tagged
  hybridPortsTaggedForVlan =
    device: vlanName:
    lib.filter (p: builtins.elem vlanName (portTaggedVlans device p)) (hybridPorts device);

  # Hybrid ports whose native (untagged) VLAN matches
  hybridPortsUntaggedForVlan =
    device: vlanName: lib.filter (p: portVlan device p == vlanName) (hybridPorts device);

  # ── Standalone trunk management ────────────────────────────────────
  # When managementPort is a trunk port, it stays standalone (like WAP ether1)
  # with VLAN sub-interfaces feeding tagged traffic into the bridge.
  # Management IP comes from untagged traffic on the hybrid uplink.
  isMgmtTrunk = device: device.managementPort != null && isTrunk device device.managementPort;

  # Sub-interface name on the standalone trunk port (RouterOS interface name)
  uplinkSubIf = port: vlanId: "${port}-v${toString vlanId}";

  # Non-mgmt VLANs — mgmt is untagged on the hybrid uplink, handled by standalone port
  nonMgmtVlans = device: lib.filterAttrs (n: _: n != "mgmt") device.vlans;

  # Sub-interface names for bridge VLAN entries (replaces trunk port in tagged/untagged lists)
  uplinkSubIfsForVlan =
    name: device: vlanName:
    if isMgmtTrunk device && vlanName != "mgmt" then
      [ (config.resource.routeros_interface_vlan."${name}_uplink_${vlanName}" "name") ]
    else
      [ ];

  # Switches that need a management VLAN interface on the bridge.
  # Either no dedicated management port, or explicitly requesting one via fallbackPort.
  # Exclude devices with trunk management — they get management via standalone port.
  switchesNeedingMgmtVlan = lib.filterAttrs (
    _: d: (d.managementPort == null || d ? fallbackPort) && !isMgmtTrunk d
  ) switches;
in
{
  # ── Bridge ──────────────────────────────────────────────────────────

  resource.routeros_interface_bridge = lib.concatMapAttrs (name: _: {
    ${name} = {
      provider = deviceProvider name;
      name = "bridge";
      vlan_filtering = true;
    };
  }) switches;

  # ── Bridge ports ────────────────────────────────────────────────────

  resource.routeros_interface_bridge_port = lib.concatMapAttrs (
    name: device:
    # Regular bridge ports (physical interfaces)
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
    # Uplink sub-interface bridge ports (for standalone trunk management)
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

  # ── Ethernet port settings (PoE, etc.) ─────────────────────────────

  resource.routeros_interface_ethernet = lib.concatMapAttrs (
    name: device:
    let
      portsWithPoe = lib.filter (p: (portCfg device p).poe or null != null) (portsForModel device.model);
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

  # ── VLAN interfaces ────────────────────────────────────────────────

  resource.routeros_interface_vlan =
    # Uplink sub-interfaces on standalone trunk port
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
    # Management VLAN interface on bridge (for DHCP client)
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

  # ── Bridge VLAN table ──────────────────────────────────────────────

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
