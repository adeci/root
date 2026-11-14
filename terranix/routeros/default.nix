{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (self.inventory) appliances lan;
  inherit (self.inventory.routeros) admin exporter;
  inherit (import ../lib.nix { inherit config lib self'; }) clanSecret setClanVar;
in
{
  imports = [
    ./switches.nix
    ./access-points.nix
  ];

  terraform.required_providers.routeros = {
    source = "terraform-routeros/routeros";
    version = "~> 1.99";
  };

  terraform.required_providers.random = {
    source = "hashicorp/random";
    version = "~> 3.9";
  };

  clanSecrets = [ admin.secret ];

  provider.routeros = lib.mapAttrsToList (name: appliance: {
    alias = name;
    hosturl = "api://${appliance.api.address}:${toString appliance.api.port}";
    username = admin.user;
    password = clanSecret admin.secret;
    insecure = true;
  }) appliances;

  resource.routeros_system_identity = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    inherit name;
  }) appliances;

  # The exporter's account: one password on every appliance, kept in the router's clan vars, reachable only from the router.
  resource.random_password.routeros_exporter = {
    length = 32;
    special = false;
  };

  resource.terraform_data.routeros_exporter_password = {
    input = config.resource.random_password.routeros_exporter "result";

    provisioner.local-exec = {
      command = "echo \"\${self.input}\" | ${setClanVar exporter.machine exporter}";
    };
  };

  resource.routeros_system_user_group = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${name}_${exporter.user}" {
      provider = "routeros.${name}";
      name = exporter.user;
      policy = [
        "api"
        "read"
      ];
      comment = "Prometheus read-only API — Managed by Terraform";
    }
  ) appliances;

  resource.routeros_system_user = lib.mapAttrs' (
    name: appliance:
    lib.nameValuePair "${name}_${exporter.user}" {
      provider = "routeros.${name}";
      name = exporter.user;
      group = config.resource.routeros_system_user_group."${name}_${exporter.user}" "name";
      password = config.resource.random_password.routeros_exporter "result";
      address = "${lan.vlans.${appliance.lan.vlan}.gateway}/32";
      disabled = false;
      comment = "Prometheus read-only API — Managed by Terraform";
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
      lib.mapAttrs' (
        service: port:
        lib.nameValuePair "${name}_disable_${service}" {
          provider = "routeros.${name}";
          numbers = service;
          inherit port;
          disabled = true;
        }
      ) disabledServices
    ) appliances;

  resource.routeros_ip_address = lib.mapAttrs' (
    name: appliance:
    lib.nameValuePair "${name}_fallback" {
      provider = "routeros.${name}";
      address = appliance.fallbackAddress;
      interface = appliance.fallbackPort;
      comment = "Static fallback — Managed by Terraform";
    }
  ) appliances;
}
