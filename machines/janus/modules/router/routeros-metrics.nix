{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (self.inventory) appliances;
  inherit (self.inventory.routeros) exporter;
  exporterPassword = config.clan.core.vars.generators.${exporter.generator}.files.${exporter.file};

  mainConfigPath = "/run/prometheus-mikrotik-exporter/config.yml";
  poeConfigPath = "/run/prometheus-mikrotik-poe-exporter/config.yml";
  poeExporterAddress = "127.0.0.1:9437";

  # The exporters' device list; the password is added when each service starts.
  devicesOf = lib.mapAttrsToList (
    name: appliance: {
      inherit name;
      inherit (appliance.api) address;
      port = toString appliance.api.port;
      inherit (exporter) user;
    }
  );

  poeAppliances = lib.filterAttrs (
    _: appliance: lib.any (port: port.poe != null) (lib.attrValues appliance.ports)
  ) appliances;

  mainBaseConfig = pkgs.writeText "routeros-exporter-base.json" (
    builtins.toJSON {
      devices = devicesOf appliances;
      features.monitor = true;
    }
  );

  poeBaseConfig = pkgs.writeText "routeros-poe-exporter-base.json" (
    builtins.toJSON {
      devices = devicesOf poeAppliances;
      features.poe = true;
    }
  );

  healthDevices = pkgs.writeText "routeros-health-devices.json" (
    builtins.toJSON (devicesOf appliances)
  );

  exporterConfig = pkgs.writeShellApplication {
    name = "routeros-exporter-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = builtins.readFile ./routeros-exporter-config.sh;
  };
in
{
  clan.core.vars.generators.${exporter.generator}.files.${exporter.file}.secret = true;

  services.prometheus.exporters.mikrotik = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9436;
    configFile = mainConfigPath;
    extraFlags = [
      "-log-format=json"
      "-log-level=info"
    ];
  };

  systemd.services.prometheus-mikrotik-exporter = {
    preStart = "${lib.getExe exporterConfig} ${mainBaseConfig} ${mainConfigPath}";

    serviceConfig = {
      LoadCredential = [
        "routeros-password:${exporterPassword.path}"
      ];
      RuntimeDirectory = "prometheus-mikrotik-exporter";
      RuntimeDirectoryMode = "0700";
    };
  };

  monitoring.scrapeTargets = {
    mikrotik =
      let
        inherit (config.services.prometheus.exporters) mikrotik;
      in
      "${mikrotik.listenAddress}:${toString mikrotik.port}";
    mikrotik-poe = poeExporterAddress;
  };

  systemd.services.prometheus-mikrotik-poe-exporter = {
    description = "Prometheus exporter for RouterOS PoE metrics";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    preStart = "${lib.getExe exporterConfig} ${poeBaseConfig} ${poeConfigPath}";

    serviceConfig = {
      DynamicUser = true;
      LoadCredential = [
        "routeros-password:${exporterPassword.path}"
      ];
      RuntimeDirectory = "prometheus-mikrotik-poe-exporter";
      RuntimeDirectoryMode = "0700";
      ExecStart = "${lib.getExe' pkgs.prometheus-mikrotik-exporter "mikrotik-exporter"} -config-file=${poeConfigPath} -port=${poeExporterAddress} -log-format=json -log-level=info";
      Restart = "always";
      RestartSec = "10s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  systemd.services.janus-routeros-health = {
    description = "Export RouterOS health sensors for Alloy textfile scraping";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.python3} ${./routeros-health.py} ${healthDevices} ${config.monitoring.textfileDirectory}/janus-routeros-health.prom";
      LoadCredential = [
        "routeros-password:${exporterPassword.path}"
      ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ config.monitoring.textfileDirectory ];
    };
  };

  systemd.timers.janus-routeros-health = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      AccuracySec = "5s";
    };
  };
}
