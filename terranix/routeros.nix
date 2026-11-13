{
  config,
  lib,
  self,
  routerosAdmin,
  clanSecret,
  safeName,
  setClanVar,
  ...
}:
let
  inherit (self.inventory) appliances lan;
  inherit (self.inventory.routeros) models exporter;

  deviceProvider = name: "routeros.${name}";
  routerosExporterSource = "${lan.vlans.mgmt.gateway}/32";
  routerosExporterPolicy = [
    "api"
    "read"
  ];

  switches = lib.filterAttrs (_: d: d.vlans != [ ]) appliances;

  modelPorts = device: models.${device.model}.ports;

  bridgePorts = device: lib.filter (p: p != device.managementPort) (modelPorts device);

  portCfg = device: port: device.ports.${port};
  isTrunk = device: port: (portCfg device port).trunk;
  isHybrid = device: port: (portCfg device port).hybrid;
  portVlan = device: port: (portCfg device port).vlan;
  portVlanId = device: port: device.vlanIds.${portVlan device port};
  portTaggedVlans = device: port: (portCfg device port).tagged;

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
  isMgmtTrunk = device: isTrunk device device.managementPort;

  uplinkSubIf = port: vlanId: "${port}-v${toString vlanId}";

  nonMgmtVlans = device: lib.filterAttrs (n: _: n != "mgmt") device.vlanIds;

  # Resource references, not plain names, so the sub-interfaces exist before the bridge VLAN entries that name them.
  uplinkSubIfsForVlan =
    name: device: vlanName:
    if isMgmtTrunk device && vlanName != "mgmt" then
      [ (config.resource.routeros_interface_vlan."${name}_uplink_${vlanName}" "name") ]
    else
      [ ];

  switchesNeedingMgmtVlan = lib.filterAttrs (_: d: d.fallbackPort != null && !isMgmtTrunk d) switches;

  # An access point's management port keeps untagged DHCP management and carries the WiFi VLANs as tagged sub-interfaces (no vlan_filtering), so the facing switch port must be hybrid.
  waps = lib.filterAttrs (_: d: d.wifi != [ ]) appliances;

  authTypes = {
    "wpa3" = [ "wpa3-psk" ];
    "wpa2" = [ "wpa2-psk" ];
    "wpa2-wpa3" = [
      "wpa2-psk"
      "wpa3-psk"
    ];
  };

  vlanInterfaceName = vlanName: "vlan${toString lan.vlans.${vlanName}.id}";

  ssidVlans = device: lib.unique (lib.mapAttrsToList (_: ssid: ssid.vlan) device.wifiNetworks);

  ssidSecrets = lib.unique (
    lib.concatMap (device: lib.mapAttrsToList (_: ssid: ssid.secret) device.wifiNetworks) (
      lib.attrValues waps
    )
  );

  primarySsidName =
    device:
    lib.findFirst (n: device.wifiNetworks.${n}.primary) null (lib.attrNames device.wifiNetworks);
  secondarySsidNames =
    device: lib.filter (n: !device.wifiNetworks.${n}.primary) (lib.attrNames device.wifiNetworks);

  radios = device: models.${device.model}.radios;
in
{
  terraform.required_providers.routeros = {
    source = "terraform-routeros/routeros";
    version = "~> 1.99";
  };

  terraform.required_providers.random = {
    source = "hashicorp/random";
    version = "~> 3.9";
  };

  clanSecrets = [ routerosAdmin.secret ] ++ ssidSecrets;

  provider.routeros = lib.mapAttrsToList (name: device: {
    alias = name;
    hosturl = "api://${device.api.address}:${toString device.api.port}";
    username = routerosAdmin.user;
    password = clanSecret routerosAdmin.secret;
    insecure = true;
  }) appliances;

  resource.random_password.routeros_exporter = {
    length = 32;
    special = false;
  };

  resource.routeros_system_user_group = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${name}_${exporter.user}" {
      provider = deviceProvider name;
      name = exporter.user;
      policy = routerosExporterPolicy;
      comment = "Prometheus read-only API — Managed by Terraform";
    }
  ) appliances;

  resource.routeros_system_user = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${name}_${exporter.user}" {
      provider = deviceProvider name;
      name = exporter.user;
      group = config.resource.routeros_system_user_group."${name}_${exporter.user}" "name";
      password = config.resource.random_password.routeros_exporter "result";
      address = routerosExporterSource;
      disabled = false;
      comment = "Prometheus read-only API — Managed by Terraform";
    }
  ) appliances;

  resource.terraform_data.routeros_exporter_password = {
    input = config.resource.random_password.routeros_exporter "result";

    provisioner.local-exec = {
      command = "echo \"\${self.input}\" | ${setClanVar exporter.machine exporter}";
    };
  };

  resource.routeros_system_identity = lib.mapAttrs (name: device: {
    provider = deviceProvider name;
    name = device.identity;
  }) appliances;

  resource.routeros_ip_address = lib.mapAttrs' (
    name: device:
    lib.nameValuePair "${name}_fallback" {
      provider = deviceProvider name;
      address = device.fallbackAddress;
      interface = if device.fallbackPort != null then device.fallbackPort else device.managementPort;
      comment = "Static fallback — Managed by Terraform";
    }
  ) appliances;

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
    ) appliances;

  resource.routeros_interface_bridge =
    let
      switchBridges = lib.concatMapAttrs (name: _: {
        ${name} = {
          provider = deviceProvider name;
          name = "bridge";
          vlan_filtering = true;
        };
      }) switches;

      wapBridges = lib.concatMapAttrs (
        name: device:
        lib.listToAttrs (
          map (vlanName: {
            name = "${name}_${vlanName}";
            value = {
              provider = deviceProvider name;
              name = "bridge-${vlanName}";
            };
          }) (ssidVlans device)
        )
      ) waps;
    in
    switchBridges // wapBridges;

  resource.routeros_interface_bridge_port =
    let
      switchBridgePorts = lib.concatMapAttrs (
        name: device:
        lib.listToAttrs (
          map (port: {
            name = "${name}_${safeName port}";
            value = {
              provider = deviceProvider name;
              bridge = config.resource.routeros_interface_bridge.${name} "name";
              interface = port;
              pvid = if isTrunk device port then device.vlanIds.${device.defaultVlan} else portVlanId device port;
              frame_types =
                if isTrunk device port || isHybrid device port then
                  "admit-all"
                else
                  "admit-only-untagged-and-priority-tagged";
              ingress_filtering = true;
            }
            // lib.optionalAttrs ((portCfg device port).label != null) {
              comment = (portCfg device port).label;
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

      wapBridgePorts = lib.concatMapAttrs (
        name: device:
        lib.listToAttrs (
          map (vlanName: {
            name = "${name}_${vlanName}";
            value = {
              provider = deviceProvider name;
              bridge = config.resource.routeros_interface_bridge."${name}_${vlanName}" "name";
              interface = config.resource.routeros_interface_vlan."${name}_${vlanName}" "name";
            };
          }) (ssidVlans device)
        )
      ) waps;
    in
    switchBridgePorts // wapBridgePorts;

  resource.routeros_interface_ethernet = lib.concatMapAttrs (
    name: device:
    let
      portsWithPoe = lib.filter (p: (portCfg device p).poe != null) (modelPorts device);
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
    let
      switchUplinkVlans = lib.concatMapAttrs (
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
      ) (lib.filterAttrs (_: isMgmtTrunk) switches);

      switchMgmtVlans = lib.concatMapAttrs (name: device: {
        "${name}_mgmt" = {
          provider = deviceProvider name;
          name = "vlan${toString device.vlanIds.mgmt}";
          interface = config.resource.routeros_interface_bridge.${name} "name";
          vlan_id = device.vlanIds.mgmt;
        };
      }) switchesNeedingMgmtVlan;

      wapVlans = lib.concatMapAttrs (
        name: device:
        lib.listToAttrs (
          map (vlanName: {
            name = "${name}_${vlanName}";
            value = {
              provider = deviceProvider name;
              name = vlanInterfaceName vlanName;
              interface = device.managementPort;
              vlan_id = lan.vlans.${vlanName}.id;
            };
          }) (ssidVlans device)
        )
      ) waps;
    in
    switchUplinkVlans // switchMgmtVlans // wapVlans;

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
    ) device.vlanIds
  ) switches;

  resource.routeros_wifi_security = lib.concatMapAttrs (
    name: device:
    lib.mapAttrs' (
      ssidName: ssidCfg:
      lib.nameValuePair "${name}_${ssidName}" {
        provider = deviceProvider name;
        name = "${name}-${ssidName}";
        authentication_types = authTypes.${ssidCfg.security};
        passphrase = clanSecret ssidCfg.secret;
      }
    ) device.wifiNetworks
  ) waps;

  resource.routeros_wifi_datapath = lib.concatMapAttrs (
    name: device:
    lib.mapAttrs' (
      ssidName: ssidCfg:
      lib.nameValuePair "${name}_${ssidName}" {
        provider = deviceProvider name;
        name = "${name}-${ssidName}";
        bridge = config.resource.routeros_interface_bridge."${name}_${ssidCfg.vlan}" "name";
      }
    ) device.wifiNetworks
  ) waps;

  resource.routeros_wifi_configuration = lib.concatMapAttrs (
    name: device:
    lib.mapAttrs' (
      ssidName: ssidCfg:
      lib.nameValuePair "${name}_${ssidName}" {
        provider = deviceProvider name;
        name = "${name}-${ssidName}";
        inherit (ssidCfg) ssid;
        country = "United States";
        mode = "ap";
        security = {
          config = config.resource.routeros_wifi_security."${name}_${ssidName}" "name";
        };
        datapath = {
          config = config.resource.routeros_wifi_datapath."${name}_${ssidName}" "name";
        };
        hide_ssid = ssidCfg.hidden;
      }
    ) device.wifiNetworks
  ) waps;

  # The radios pre-exist after netinstall; the import blocks below bring them into state on first apply.
  resource.routeros_wifi = lib.concatMapAttrs (
    name: device:
    let
      primary = primarySsidName device;
      secondaries = secondarySsidNames device;
    in
    lib.listToAttrs (
      map (radio: {
        name = "${name}_${radio.name}";
        value = {
          provider = deviceProvider name;
          inherit (radio) name;
          disabled = false;
          configuration = {
            config = config.resource.routeros_wifi_configuration."${name}_${primary}" "name";
          };
          security = {
            config = config.resource.routeros_wifi_security."${name}_${primary}" "name";
            authentication_types =
              lib.concatStringsSep ","
                authTypes.${device.wifiNetworks.${primary}.security};
            passphrase = clanSecret device.wifiNetworks.${primary}.secret;
          };
          datapath = {
            config = config.resource.routeros_wifi_datapath."${name}_${primary}" "name";
          };
        };
      }) (radios device)
    )
    // lib.listToAttrs (
      lib.concatMap (
        radio:
        map (ssidName: {
          name = "${name}_${radio.name}_${ssidName}";
          value = {
            provider = deviceProvider name;
            name = "${radio.name}-${ssidName}";
            master_interface = config.resource.routeros_wifi."${name}_${radio.name}" "name";
            disabled = false;
            configuration = {
              config = config.resource.routeros_wifi_configuration."${name}_${ssidName}" "name";
            };
          };
        }) secondaries
      ) (radios device)
    )
  ) waps;

  import = lib.concatLists (
    lib.mapAttrsToList (
      name: device:
      map (radio: {
        to = "routeros_wifi.${name}_${radio.name}";
        inherit (radio) id;
        provider = deviceProvider name;
      }) (radios device)
    ) waps
  );
}
