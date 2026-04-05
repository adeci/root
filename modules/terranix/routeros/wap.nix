# RouterOS WAP resources — WiFi, security, datapaths, bridge
# Applied to devices that have a `wifi` attribute in their data.
#
# Each SSID gets:
#   - routeros_wifi_security       (passphrase + auth type)
#   - routeros_wifi_datapath       (VLAN mapping via bridge)
#   - routeros_wifi_configuration  (SSID + security + datapath binding)
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

  # ── WiFi security profiles ──────────────────────────────────────────

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

  # ── WiFi datapaths (SSID → VLAN mapping) ───────────────────────────

  resource.routeros_wifi_datapath = lib.concatMapAttrs (
    name: device:
    lib.mapAttrs' (
      ssidName: ssidCfg:
      lib.nameValuePair "${name}_${ssidName}" {
        provider = deviceProvider name;
        name = "${name}-${ssidName}";
        bridge = config.resource.routeros_interface_bridge.${name} "name";
        vlan_id = ssidCfg.vlan;
      }
    ) device.wifi
  ) waps;

  # ── WiFi configurations (ties SSID + security + datapath) ──────────

  resource.routeros_wifi_configuration = lib.concatMapAttrs (
    name: device:
    lib.mapAttrs' (
      ssidName: ssidCfg:
      lib.nameValuePair "${name}_${ssidName}" {
        provider = deviceProvider name;
        name = "${name}-${ssidName}";
        inherit (ssidCfg) ssid;
        country = "United States";
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

  # ── Bridge for WAPs ─────────────────────────────────────────────────
  # WiFi interfaces join the bridge via datapaths.
  # VLAN filtering tags traffic per SSID.

  resource.routeros_interface_bridge = lib.concatMapAttrs (name: _: {
    ${name} = {
      provider = deviceProvider name;
      name = "bridge";
      vlan_filtering = true;
    };
  }) waps;
}
