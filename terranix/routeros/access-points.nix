{
  clan-cli,
  config,
  lib,
  self,
  ...
}:
let
  inherit (self.inventory)
    appliances
    lan
    wifi
    wifiBlocked
    ;
  inherit (self.inventory.routeros) models;
  inherit (import ../lib.nix { inherit clan-cli lib; }) clanSecret safeName;

  # Each Wi-Fi VLAN: tagged sub-interface on the management port, own bridge, no vlan_filtering.
  accessPoints = lib.filterAttrs (_: appliance: appliance.wifi != null) appliances;

  authenticationTypes = {
    "wpa3" = [ "wpa3-psk" ];
    "wpa2" = [ "wpa2-psk" ];
    "wpa2-wpa3" = [
      "wpa2-psk"
      "wpa3-psk"
    ];
  };

  # Radios exist after netinstall; the import blocks bring them into state on first apply.
  radios = accessPoint: models.${accessPoint.model}.radios;

  # The VLANs an access point's networks join.
  wifiVlans = accessPoint: lib.unique (map (network: wifi.${network}.vlan) accessPoint.wifi);

  # One resource per access point and Wi-Fi VLAN or network, named <ap>_<key>.
  forEachAccessPoint =
    keys: resource:
    lib.concatMapAttrs (
      name: accessPoint:
      lib.genAttrs' (keys accessPoint) (key: lib.nameValuePair "${name}_${key}" (resource name key))
    ) accessPoints;
  forEachVlan = forEachAccessPoint wifiVlans;
  forEachNetwork = forEachAccessPoint (accessPoint: accessPoint.wifi);
in
{
  clanSecrets = lib.unique (
    map (network: wifi.${network}.secret) (
      lib.concatMap (accessPoint: accessPoint.wifi) (lib.attrValues accessPoints)
    )
  );

  resource.routeros_interface_vlan = forEachVlan (
    name: vlan: {
      provider = "routeros.${name}";
      name = "vlan${toString lan.vlans.${vlan}.id}";
      interface = accessPoints.${name}.managementPort;
      vlan_id = lan.vlans.${vlan}.id;
    }
  );

  resource.routeros_interface_bridge = forEachVlan (
    name: vlan: {
      provider = "routeros.${name}";
      name = "bridge-${vlan}";
    }
  );

  resource.routeros_interface_bridge_port = forEachVlan (
    name: vlan: {
      provider = "routeros.${name}";
      bridge = config.resource.routeros_interface_bridge."${name}_${vlan}" "name";
      interface = config.resource.routeros_interface_vlan."${name}_${vlan}" "name";
    }
  );

  resource.routeros_wifi_security = forEachNetwork (
    name: network: {
      provider = "routeros.${name}";
      name = "${name}-${network}";
      authentication_types = authenticationTypes.${wifi.${network}.security};
      passphrase = clanSecret wifi.${network}.secret;
    }
  );

  resource.routeros_wifi_datapath = forEachNetwork (
    name: network: {
      provider = "routeros.${name}";
      name = "${name}-${network}";
      bridge = config.resource.routeros_interface_bridge."${name}_${wifi.${network}.vlan}" "name";
    }
  );

  resource.routeros_wifi_configuration = forEachNetwork (
    name: network: {
      provider = "routeros.${name}";
      name = "${name}-${network}";
      inherit (wifi.${network}) ssid;
      country = "United States";
      mode = "ap";
      security = {
        config = config.resource.routeros_wifi_security."${name}_${network}" "name";
      };
      datapath = {
        config = config.resource.routeros_wifi_datapath."${name}_${network}" "name";
      };
      hide_ssid = wifi.${network}.hidden;
    }
  );

  # The first network on each radio's main interface, the rest as virtual interfaces.
  resource.routeros_wifi = lib.concatMapAttrs (
    name: accessPoint:
    let
      primary = lib.head accessPoint.wifi;
    in
    lib.genAttrs' (radios accessPoint) (
      radio:
      lib.nameValuePair "${name}_${radio}" {
        provider = "routeros.${name}";
        name = radio;
        disabled = false;
        configuration = {
          config = config.resource.routeros_wifi_configuration."${name}_${primary}" "name";
        };
        security = {
          config = config.resource.routeros_wifi_security."${name}_${primary}" "name";
          authentication_types = lib.concatStringsSep "," authenticationTypes.${wifi.${primary}.security};
          passphrase = clanSecret wifi.${primary}.secret;
        };
        datapath = {
          config = config.resource.routeros_wifi_datapath."${name}_${primary}" "name";
        };
      }
    )
    // lib.listToAttrs (
      lib.concatMap (
        radio:
        map (
          network:
          lib.nameValuePair "${name}_${radio}_${network}" {
            provider = "routeros.${name}";
            name = "${radio}-${network}";
            master_interface = config.resource.routeros_wifi."${name}_${radio}" "name";
            disabled = false;
            configuration = {
              config = config.resource.routeros_wifi_configuration."${name}_${network}" "name";
            };
          }
        ) (lib.tail accessPoint.wifi)
      ) (radios accessPoint)
    )
  ) accessPoints;

  # Only the MAC may shape an entry: provider 1.99.1 crashes updating one in place.
  resource.routeros_wifi_access_list = lib.concatMapAttrs (
    name: _:
    lib.genAttrs' wifiBlocked (
      mac:
      lib.nameValuePair "${name}_${safeName mac}" {
        provider = "routeros.${name}";
        # The provider takes upper case only.
        mac_address = lib.toUpper mac;
        action = "reject";
        comment = "Blocked — Managed by Terraform";
      }
    )
  ) accessPoints;

  import = lib.concatLists (
    lib.mapAttrsToList (
      name: accessPoint:
      map (radio: {
        to = "routeros_wifi.${name}_${radio}";
        id = radio;
        provider = "routeros.${name}";
      }) (radios accessPoint)
    ) accessPoints
  );
}
