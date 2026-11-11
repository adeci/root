{
  config,
  self,
  self',
  inputs',
  lib,
  routerosAdmin,
  ...
}:
let
  inherit (self.resources) homelan;
  inherit (self.resources.routeros) devices exporter;
  inherit (inputs'.clan-core.packages) clan-cli;

  deviceProvider = name: "routeros.${name}";
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
    version = "~> 3.9";
  };

  terraform.required_providers.external = {
    source = "registry.opentofu.org/hashicorp/external";
    version = "~> 2.0";
  };

  data.external.${routerosAdmin.secret} = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      routerosAdmin.secret
    ];
  };

  provider.routeros = lib.mapAttrsToList (name: device: {
    alias = name;
    hosturl = "api://${device.host}:${toString device.port}";
    username = routerosAdmin.user;
    password = config.data.external.${routerosAdmin.secret} "result.secret";
    insecure = true;
  }) devices;

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
  ) devices;

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
  ) devices;

  resource.terraform_data.routeros_exporter_password = {
    input = config.resource.random_password.routeros_exporter "result";

    provisioner.local-exec = {
      command = "echo \"\${self.input}\" | ${lib.getExe clan-cli} vars set ${exporter.machine} ${exporter.generator}/${exporter.file}";
    };
  };

  resource.routeros_system_identity = lib.mapAttrs (name: device: {
    provider = deviceProvider name;
    name = device.identity;
  }) devices;

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
  ) devices;

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
    ) devices;
}
