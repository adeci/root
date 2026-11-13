{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (self.inventory) appliances lan wifi;
  inherit (self.inventory.routeros) models;
  inherit (import ../lib.nix { inherit config lib self'; }) clanSecret;

  # The management port keeps untagged DHCP management and carries each Wi-Fi VLAN as a tagged sub-interface with a bridge of its own, without vlan_filtering.
  accessPoints = lib.filterAttrs (_: appliance: appliance.wifi != [ ]) appliances;

  authenticationTypes = {
    "wpa3" = [ "wpa3-psk" ];
    "wpa2" = [ "wpa2-psk" ];
    "wpa2-wpa3" = [
      "wpa2-psk"
      "wpa3-psk"
    ];
  };

  # The radios pre-exist after netinstall; the import blocks bring them into state on first apply.
  radios = accessPoint: models.${accessPoint.model}.radios;

  # A resource for each Wi-Fi VLAN or network of each access point, named <access point>_<VLAN or network>.
  forEachAccessPoint =
    keys: resource:
    lib.concatMapAttrs (
      name: accessPoint:
      lib.genAttrs' (keys accessPoint) (key: lib.nameValuePair "${name}_${key}" (resource name key))
    ) accessPoints;
  forEachVlan = forEachAccessPoint (accessPoint: accessPoint.wifiVlans);
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

  # Each radio's main interface broadcasts the primary network, and a virtual interface each other network.
  resource.routeros_wifi = lib.concatMapAttrs (
    name: accessPoint:
    let
      primary = accessPoint.primaryWifi;
    in
    lib.genAttrs' (radios accessPoint) (
      radio:
      lib.nameValuePair "${name}_${radio.name}" {
        provider = "routeros.${name}";
        inherit (radio) name;
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
          lib.nameValuePair "${name}_${radio.name}_${network}" {
            provider = "routeros.${name}";
            name = "${radio.name}-${network}";
            master_interface = config.resource.routeros_wifi."${name}_${radio.name}" "name";
            disabled = false;
            configuration = {
              config = config.resource.routeros_wifi_configuration."${name}_${network}" "name";
            };
          }
        ) accessPoint.otherWifi
      ) (radios accessPoint)
    )
  ) accessPoints;

  import = lib.concatLists (
    lib.mapAttrsToList (
      name: accessPoint:
      map (radio: {
        to = "routeros_wifi.${name}_${radio.name}";
        inherit (radio) id;
        provider = "routeros.${name}";
      }) (radios accessPoint)
    ) accessPoints
  );
}
