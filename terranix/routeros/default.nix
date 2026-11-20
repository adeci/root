{
  clan-cli,
  config,
  lib,
  self,
  tunnelPorts,
  ...
}:
let
  inherit (self.inventory) appliances lan;
  inherit (self.inventory.routeros) admin exporter;
  inherit (import ../lib.nix { inherit clan-cli lib; }) clanSecret safeName setClanVar;

  # The router's address on an appliance's management VLAN.
  routerAddress = appliance: lan.vlans.${appliance.lan.vlan}.gateway;
in
{
  imports = [
    ./switches.nix
    ./access-points.nix
  ];

  clanSecrets = [ admin.secret ];

  # The net apps' tunnel through the router forwards each appliance's API to its port in tunnelPorts.
  provider.routeros = lib.mapAttrsToList (name: _: {
    alias = name;
    hosturl = "api://127.0.0.1:${toString tunnelPorts.${name}}";
    username = admin.user;
    password = clanSecret admin.secret;
    insecure = true;
  }) appliances;

  resource.routeros_system_identity = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    inherit name;
  }) appliances;

  resource.routeros_system_ntp_client = lib.mapAttrs (name: appliance: {
    provider = "routeros.${name}";
    enabled = true;
    servers = [ (routerAddress appliance) ];
  }) appliances;

  # The time zone lookup asks MikroTik's cloud, which the router never lets them reach.
  resource.routeros_system_clock = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    time_zone_autodetect = false;
  }) appliances;

  # The exporter's account: one password on every appliance, kept in the router's clan vars, reachable only from the router.
  resource.random_password.routeros_exporter = {
    length = 32;
    special = false;
  };

  resource.terraform_data.routeros_exporter_password = {
    input = config.resource.random_password.routeros_exporter "result";

    provisioner.local-exec = {
      # Off the command line, which other local processes can read.
      environment.EXPORTER_PASSWORD = "\${sensitive(self.input)}";
      command = ''
        printf '%s\n' "$EXPORTER_PASSWORD" | ${setClanVar exporter.machine exporter}
      '';
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
      address = "${routerAddress appliance}/32";
      disabled = false;
      comment = "Prometheus read-only API — Managed by Terraform";
    }
  ) appliances;

  resource.routeros_ip_service =
    let
      disabledServices = {
        telnet = 23;
        ftp = 21;
        www = 80;
        winbox = 8291;
        api-ssl = 8729;
      };
      # The logins that stay answer only the management VLAN, which the router reaches them on, and the fallback network.
      logins = appliance: {
        ssh = 22;
        api = appliance.api.port;
      };
    in
    lib.concatMapAttrs (
      name: appliance:
      lib.mapAttrs' (
        service: port:
        lib.nameValuePair "${name}_disable_${safeName service}" {
          provider = "routeros.${name}";
          numbers = service;
          inherit port;
          disabled = true;
        }
      ) disabledServices
      // lib.mapAttrs' (
        service: port:
        lib.nameValuePair "${name}_${service}" {
          provider = "routeros.${name}";
          numbers = service;
          inherit port;
          address = "${lan.vlans.${appliance.lan.vlan}.cidr},${lan.fallbackNetwork}";
        }
      ) (logins appliance)
    ) appliances;

  resource.routeros_tool_mac_server = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    allowed_interface_list = "none";
  }) appliances;

  resource.routeros_tool_mac_server_winbox = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    allowed_interface_list = "none";
  }) appliances;

  resource.routeros_tool_mac_server_ping = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    enabled = false;
  }) appliances;

  resource.routeros_tool_bandwidth_server = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    enabled = false;
  }) appliances;

  resource.routeros_ip_neighbor_discovery_settings = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    discover_interface_list = "none";
  }) appliances;

  # Their bridges carry the clients' IPv6 without needing any of their own.
  resource.routeros_ipv6_settings = lib.mapAttrs (name: _: {
    provider = "routeros.${name}";
    disable_ipv6 = true;
  }) appliances;

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
