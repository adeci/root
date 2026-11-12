# The management port keeps untagged DHCP management and carries the WiFi VLANs as tagged sub-interfaces (no vlan_filtering), so the facing switch port must be hybrid.
{
  config,
  self,
  lib,
  deviceProvider,
  clanSecret,
  ...
}:
let
  inherit (self.resources) homelan;
  inherit (self.resources.routeros) devices models;

  waps = lib.filterAttrs (_: d: d ? wifi) devices;

  authTypes = {
    "wpa3" = [ "wpa3-psk" ];
    "wpa2" = [ "wpa2-psk" ];
    "wpa2-wpa3" = [
      "wpa2-psk"
      "wpa3-psk"
    ];
  };

  vlanId = name: homelan.vlans.${name}.id;
  vlanInterfaceName = name: "vlan${toString (vlanId name)}";

  deviceVlans = device: lib.unique (lib.mapAttrsToList (_: ssid: ssid.vlan) device.wifi);

  primarySsidName =
    device: lib.findFirst (n: device.wifi.${n}.primary or false) null (lib.attrNames device.wifi);
  secondarySsidNames =
    device: lib.filter (n: !(device.wifi.${n}.primary or false)) (lib.attrNames device.wifi);

  radios = device: models.${device.model}.radios;
in
{
  clanSecrets = lib.unique (
    lib.concatMap (device: lib.mapAttrsToList (_: ssidCfg: ssidCfg.secret) device.wifi) (
      lib.attrValues waps
    )
  );

  resource.routeros_interface_vlan = lib.concatMapAttrs (
    name: device:
    lib.listToAttrs (
      map (vlanName: {
        name = "${name}_${vlanName}";
        value = {
          provider = deviceProvider name;
          name = vlanInterfaceName vlanName;
          interface = device.managementPort;
          vlan_id = vlanId vlanName;
        };
      }) (deviceVlans device)
    )
  ) waps;

  resource.routeros_interface_bridge = lib.concatMapAttrs (
    name: device:
    lib.listToAttrs (
      map (vlanName: {
        name = "${name}_${vlanName}";
        value = {
          provider = deviceProvider name;
          name = "bridge-${vlanName}";
        };
      }) (deviceVlans device)
    )
  ) waps;

  resource.routeros_interface_bridge_port = lib.concatMapAttrs (
    name: device:
    lib.listToAttrs (
      map (vlanName: {
        name = "${name}_${vlanName}";
        value = {
          provider = deviceProvider name;
          bridge = config.resource.routeros_interface_bridge."${name}_${vlanName}" "name";
          interface = config.resource.routeros_interface_vlan."${name}_${vlanName}" "name";
        };
      }) (deviceVlans device)
    )
  ) waps;

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
    ) device.wifi
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
    ) device.wifi
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
        hide_ssid = ssidCfg.hidden or false;
      }
    ) device.wifi
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
            authentication_types = lib.concatStringsSep "," authTypes.${device.wifi.${primary}.security};
            passphrase = clanSecret device.wifi.${primary}.secret;
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
