# RouterOS provider, identity, fallback IPs, service hardening
# Shared across all device types (switches + WAPs).
{
  config,
  self,
  self',
  inputs',
  lib,
  ...
}:
let
  inherit (self.resources) homelan routeros;
  inherit (inputs'.clan-core.packages) clan-cli;

  deviceProvider = name: "routeros.${name}";
  routerosExporterUser = "prometheus";
  routerosExporterSource = "${homelan.vlans.mgmt.gateway}/32";
  routerosExporterPolicy = [
    "api"
    "read"
  ];
in
{
  terraform.required_providers.routeros = {
    source = "terraform-routeros/routeros";
    version = "~> 1.99";
  };

  terraform.required_providers.random = {
    source = "hashicorp/random";
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

  # ── Prometheus API user ───────────────────────────────────────────

  resource.random_password.routeros_exporter = {
    length = 32;
    special = false;
  };

  resource.routeros_system_user_group = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${name}_${routerosExporterUser}" {
      provider = deviceProvider name;
      name = routerosExporterUser;
      policy = routerosExporterPolicy;
      comment = "Prometheus read-only API — Managed by Terraform";
    }
  ) routeros;

  resource.routeros_system_user = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${name}_${routerosExporterUser}" {
      provider = deviceProvider name;
      name = routerosExporterUser;
      group = config.resource.routeros_system_user_group."${name}_${routerosExporterUser}" "name";
      password = config.resource.random_password.routeros_exporter "result";
      address = routerosExporterSource;
      disabled = false;
      comment = "Prometheus read-only API — Managed by Terraform";
    }
  ) routeros;

  resource.terraform_data.routeros_exporter_password = {
    input = config.resource.random_password.routeros_exporter "result";

    provisioner.local-exec = {
      command = "echo \"\${self.input}\" | ${lib.getExe clan-cli} vars set janus routeros-exporter/password";
    };
  };

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
