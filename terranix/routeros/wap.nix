# ether1 keeps untagged DHCP management and carries the WiFi VLANs as tagged sub-interfaces (no vlan_filtering), so the facing switch port must be hybrid.
{
  config,
  self,
  self',
  lib,
  ...
}:
let
  inherit (self.resources) homelan;
  inherit (self.resources.routeros) devices;

  waps = lib.filterAttrs (_: d: d ? wifi) devices;

  deviceProvider = name: "routeros.${name}";

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

  # On cAP ax wifi1 is 5GHz and wifi2 2.4GHz; these ids are stable after netinstall.
  radios = [
    {
      name = "wifi1";
      id = "*2";
    }
    {
      name = "wifi2";
      id = "*3";
    }
  ];
in
{
  data.external =
    let
      allSecrets = lib.unique (
        lib.concatMap (device: lib.mapAttrsToList (_: ssidCfg: ssidCfg.secret) device.wifi) (
          lib.attrValues waps
        )
      );
    in
    lib.listToAttrs (
      map (secret: {
        name = secret;
        value.program = [
          (lib.getExe self'.packages.get-clan-secret)
          secret
        ];
      }) allSecrets
    );

  resource.routeros_interface_vlan = lib.concatMapAttrs (
    name: device:
    lib.listToAttrs (
      map (vlanName: {
        name = "${name}_${vlanName}";
        value = {
          provider = deviceProvider name;
          name = vlanInterfaceName vlanName;
          interface = "ether1";
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
        passphrase = config.data.external.${ssidCfg.secret} "result.secret";
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

  # wifi1/wifi2 pre-exist after netinstall; the import blocks below bring them into state on first apply.
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
            passphrase = config.data.external.${device.wifi.${primary}.secret} "result.secret";
          };
          datapath = {
            config = config.resource.routeros_wifi_datapath."${name}_${primary}" "name";
          };
        };
      }) radios
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
      ) radios
    )
  ) waps;

  import = lib.concatMap (
    name:
    map (radio: {
      to = "routeros_wifi.${name}_${radio.name}";
      inherit (radio) id;
      provider = deviceProvider name;
    }) radios
  ) (lib.attrNames waps);
}
