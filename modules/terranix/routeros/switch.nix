# RouterOS switch resources — bridge, ports, VLANs
# Applied to devices that have a `vlans` attribute in their data.
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
  portVlan = device: port: (portCfg device port).vlan or device.defaultVlan;
  portVlanId = device: port: device.vlans.${portVlan device port};

  trunkPorts = device: lib.filter (isTrunk device) (bridgePorts device);
  accessPorts = device: lib.filter (p: !isTrunk device p) (bridgePorts device);
  accessPortsForVlan =
    device: vlanName: lib.filter (p: portVlan device p == vlanName) (accessPorts device);

  # Switches that need a management VLAN interface on the bridge.
  # Either no dedicated management port, or explicitly requesting one via fallbackPort.
  switchesNeedingMgmtVlan = lib.filterAttrs (
    _: d: d.managementPort == null || d ? fallbackPort
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
    lib.listToAttrs (
      map (port: {
        name = "${name}_${safeName port}";
        value = {
          provider = deviceProvider name;
          bridge = config.resource.routeros_interface_bridge.${name} "name";
          interface = port;
          pvid = if isTrunk device port then device.vlans.${device.defaultVlan} else portVlanId device port;
          frame_types =
            if isTrunk device port then "admit-all" else "admit-only-untagged-and-priority-tagged";
          ingress_filtering = true;
        }
        // lib.optionalAttrs ((portCfg device port).comment or null != null) {
          inherit ((portCfg device port)) comment;
        };
      }) (bridgePorts device)
    )
  ) switches;

  # ── Bridge VLANs ───────────────────────────────────────────────────

  resource.routeros_interface_vlan = lib.concatMapAttrs (name: device: {
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
        tagged = [ "bridge" ] ++ trunkPorts device;
        untagged = accessPortsForVlan device vlanName;
      }
    ) device.vlans
  ) switches;
}
