# RouterOS WAP resources — WiFi + VLAN bridging (Approach B)
# Applied to devices that have a `wifi` attribute in their data.
#
# Management: ether1 stays standalone with DHCP client (safe, same as switches).
# WiFi VLANs: VLAN sub-interfaces on ether1 carry tagged traffic from the switch.
# Per-VLAN bridges connect each VLAN sub-interface to its WiFi interfaces.
# No vlan_filtering needed — traffic is already separated by sub-interfaces.
#
# The switch port facing the WAP must be a hybrid port: native VLAN for
# management (untagged) + tagged VLANs for WiFi traffic.
#
# WiFi: one SSID is marked primary and gets bound to the physical radios
# (wifi1=5GHz, wifi2=2.4GHz). These pre-exist after netinstall and are
# imported via declarative import blocks. Secondary SSIDs get virtual
# interfaces created under each radio — these are new resources, no import.
{
  config,
  self,
  self',
  lib,
  ...
}:
let
  inherit (self.resources) routeros;

  # Only devices with wifi (WAPs, not switches)
  waps = lib.filterAttrs (_: d: d ? wifi) routeros;

  deviceProvider = name: "routeros.${name}";

  # Map our security names to RouterOS authentication_types
  authTypes = {
    "wpa3" = [ "wpa3-psk" ];
    "wpa2" = [ "wpa2-psk" ];
    "wpa2-wpa3" = [
      "wpa2-psk"
      "wpa3-psk"
    ];
  };

  # VLAN name from ID (for resource naming)
  vlanName =
    id:
    {
      "10" = "trusted";
      "20" = "iot";
      "30" = "guest";
    }
    .${toString id};

  # Unique VLAN IDs used by a device's WiFi config
  deviceVlans = device: lib.unique (lib.mapAttrsToList (_: ssid: ssid.vlan) device.wifi);

  # Split SSIDs into primary (bound to physical radios) and secondary (virtual interfaces)
  primarySsidName =
    device: lib.findFirst (n: device.wifi.${n}.primary or false) null (lib.attrNames device.wifi);
  secondarySsidNames =
    device: lib.filter (n: !(device.wifi.${n}.primary or false)) (lib.attrNames device.wifi);

  # Physical radios — wifi1 is 5GHz, wifi2 is 2.4GHz on cAP ax.
  # IDs are stable after netinstall: wifi1=*2, wifi2=*3.
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
  # ── WiFi secrets ───────────────────────────────────────────────────
  # Deduplicated — multiple WAPs sharing the same secret name get one data source.

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

  # ── VLAN sub-interfaces on ether1 ──────────────────────────────────

  resource.routeros_interface_vlan = lib.concatMapAttrs (
    name: device:
    lib.listToAttrs (
      map (vlanId: {
        name = "${name}_${vlanName vlanId}";
        value = {
          provider = deviceProvider name;
          name = "vlan${toString vlanId}";
          interface = "ether1";
          vlan_id = vlanId;
        };
      }) (deviceVlans device)
    )
  ) waps;

  # ── Per-VLAN bridges ───────────────────────────────────────────────

  resource.routeros_interface_bridge = lib.concatMapAttrs (
    name: device:
    lib.listToAttrs (
      map (vlanId: {
        name = "${name}_${vlanName vlanId}";
        value = {
          provider = deviceProvider name;
          name = "bridge-${vlanName vlanId}";
        };
      }) (deviceVlans device)
    )
  ) waps;

  # ── Bridge ports (VLAN sub-interface → bridge) ─────────────────────

  resource.routeros_interface_bridge_port = lib.concatMapAttrs (
    name: device:
    lib.listToAttrs (
      map (vlanId: {
        name = "${name}_${vlanName vlanId}";
        value = {
          provider = deviceProvider name;
          bridge = config.resource.routeros_interface_bridge."${name}_${vlanName vlanId}" "name";
          interface = config.resource.routeros_interface_vlan."${name}_${vlanName vlanId}" "name";
        };
      }) (deviceVlans device)
    )
  ) waps;

  # ── WiFi security profiles ────────────────────────────────────────

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

  # ── WiFi datapaths (SSID → per-VLAN bridge) ───────────────────────

  resource.routeros_wifi_datapath = lib.concatMapAttrs (
    name: device:
    lib.mapAttrs' (
      ssidName: ssidCfg:
      lib.nameValuePair "${name}_${ssidName}" {
        provider = deviceProvider name;
        name = "${name}-${ssidName}";
        bridge = config.resource.routeros_interface_bridge."${name}_${vlanName ssidCfg.vlan}" "name";
      }
    ) device.wifi
  ) waps;

  # ── WiFi configurations (SSID + security + datapath + mode) ───────

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

  # ── Physical radio interfaces (imported) ───────────────────────────
  # wifi1/wifi2 pre-exist after netinstall. Import blocks bring them into
  # state on first apply. Each gets the primary SSID configuration.

  resource.routeros_wifi = lib.concatMapAttrs (
    name: device:
    let
      primary = primarySsidName device;
      secondaries = secondarySsidNames device;
    in
    # Physical radios — primary SSID
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
        };
      }) radios
    )
    # Virtual interfaces — secondary SSIDs on each radio
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

  # ── Import blocks for pre-existing physical radios ─────────────────

  import = lib.concatMap (
    name:
    map (radio: {
      to = "routeros_wifi.${name}_${radio.name}";
      inherit (radio) id;
      provider = deviceProvider name;
    }) radios
  ) (lib.attrNames waps);
}
