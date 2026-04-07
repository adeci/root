# RouterOS provider, identity, fallback IPs, service hardening
# Shared across all device types (switches + WAPs).
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
in
{
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

  # ── System identity ───────────────────────────────────────────────

  resource.routeros_system_identity = lib.mapAttrs (name: device: {
    provider = deviceProvider name;
    name = device.identity;
  }) routeros;

  # ── Fallback IP on management port ────────────────────────────────

  resource.routeros_ip_address = lib.concatMapAttrs (
    name: device:
    lib.optionalAttrs (device ? fallbackAddress) {
      "${name}_fallback" = {
        provider = deviceProvider name;
        address = device.fallbackAddress;
        interface = device.fallbackPort or device.managementPort;
        comment = "Static fallback — Managed by Terraform";
      };
    }
  ) routeros;

  # ── Disable unused services ───────────────────────────────────────

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
