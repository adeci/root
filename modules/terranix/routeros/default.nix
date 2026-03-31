# RouterOS provider logic
# Data layer consumed thru self.resources.routeros.<device>
{
  config,
  self,
  self',
  lib,
  ...
}:
let
  inherit (self.resources) routeros;

  deviceProvider = name: "routeros.${name}";
  safeName = builtins.replaceStrings [ "-" ] [ "_" ];

  # ── Model → port list mapping ────────────────────────────────────
  modelPorts = {
    "CRS328-24P-4S+RM" =
      (builtins.genList (i: "ether${toString (i + 1)}") 24)
      ++ (builtins.genList (i: "sfp-sfpplus${toString (i + 1)}") 4);
    "CRS310-8G+2S+IN" =
      (builtins.genList (i: "ether${toString (i + 1)}") 8)
      ++ (builtins.genList (i: "sfp-sfpplus${toString (i + 1)}") 2);
  };

  # ── Per-device helpers ───────────────────────────────────────────
  # Bridge ports = all model ports minus the management port
  bridgePorts = device: lib.filter (p: p != device.managementPort) modelPorts.${device.model};

  portCfg = device: port: device.ports.${port} or { };
  isTrunk = device: port: (portCfg device port).trunk or false;
  portVlan = device: port: (portCfg device port).vlan or device.defaultVlan;
  portVlanId = device: port: device.vlans.${portVlan device port};

  trunkPorts = device: lib.filter (isTrunk device) (bridgePorts device);
  accessPorts = device: lib.filter (p: !isTrunk device p) (bridgePorts device);

  accessPortsForVlan =
    device: vlanName: lib.filter (p: portVlan device p == vlanName) (accessPorts device);
in
{
  # ── Provider ────────────────────────────────────────────────────────

  terraform.required_providers.routeros = {
    source = "terraform-routeros/routeros";
    version = "~> 1.99";
  };

  data.external.routeros-password = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "routeros-password"
    ];
  };

  provider.routeros = lib.mapAttrsToList (name: device: {
    alias = name;
    hosturl = "api://${device.host}:${toString device.port}";
    username = "admin";
    password = config.data.external.routeros-password "result.secret";
    insecure = true;
  }) routeros;

  # ── System identity ─────────────────────────────────────────────────

  resource.routeros_system_identity = lib.mapAttrs (name: device: {
    provider = deviceProvider name;
    name = device.identity;
  }) routeros;

  # ── Bridge ──────────────────────────────────────────────────────────
  # Management port (ether1) is NOT in the bridge — standalone with DHCP.
  # vlan_filtering is always true. Safe because management is unaffected.

  resource.routeros_interface_bridge = lib.concatMapAttrs (
    name: device:
    lib.optionalAttrs (device ? vlans) {
      ${name} = {
        provider = deviceProvider name;
        name = "bridge";
        vlan_filtering = true;
      };
    }
  ) routeros;

  # ── Bridge ports ────────────────────────────────────────────────────
  # Every port EXCEPT managementPort joins the bridge.

  resource.routeros_interface_bridge_port = lib.concatMapAttrs (
    name: device:
    lib.optionalAttrs (device ? vlans) (
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
    )
  ) routeros;

  # ── Bridge VLANs ───────────────────────────────────────────────────
  # Bridge CPU is NOT a member of any VLAN — pure L2 switching.
  # Management goes through standalone ether1, not the bridge.

  resource.routeros_interface_bridge_vlan = lib.concatMapAttrs (
    name: device:
    lib.optionalAttrs (device ? vlans) (
      lib.mapAttrs' (
        vlanName: vlanId:
        lib.nameValuePair "${name}_${vlanName}" {
          provider = deviceProvider name;
          bridge = config.resource.routeros_interface_bridge.${name} "name";
          vlan_ids = [ vlanId ];
          tagged = trunkPorts device;
          untagged = accessPortsForVlan device vlanName;
        }
      ) device.vlans
    )
  ) routeros;

  # ── Fallback IP on management port ─────────────────────────────────
  # Static IP on ether1 as a safety net if DHCP fails.
  # Primary connectivity is via DHCP (static lease on router).

  resource.routeros_ip_address = lib.concatMapAttrs (
    name: device:
    lib.optionalAttrs (device ? fallbackAddress) {
      "${name}_fallback" = {
        provider = deviceProvider name;
        address = device.fallbackAddress;
        interface = device.managementPort;
        comment = "Static fallback — Managed by Terraform";
      };
    }
  ) routeros;

  # ── Disable unused services ─────────────────────────────────────────

  resource.routeros_ip_service =
    let
      disabledServices = {
        telnet = 23;
        ftp = 21;
      };
    in
    lib.concatMapAttrs (
      name: _:
      lib.concatMapAttrs (svc: port: {
        "${name}_disable_${svc}" = {
          provider = deviceProvider name;
          numbers = svc;
          inherit port;
          disabled = true;
        };
      }) disabledServices
    ) routeros;
}
