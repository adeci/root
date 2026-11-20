{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  # Pinged every second for latency percentiles, and every minute with the appliances.
  internetHosts = {
    cloudflare_dns = "1.1.1.1";
    google_dns = "8.8.8.8";
  };

  smokepingConfig = (pkgs.formats.yaml { }).generate "janus-smokeping.yml" {
    targets = lib.mapAttrsToList (target: address: {
      hosts = [ address ];
      interval = "1s";
      network = "ip4";
      protocol = "icmp";
      labels = {
        group = "internet";
        inherit target;
      };
    }) internetHosts;
  };

  probeTargets = pkgs.writeText "janus-network-probe-targets.tsv" (
    lib.concatLines (
      lib.mapAttrsToList (name: address: "${name}\t${address}\tinternet") internetHosts
      ++ lib.mapAttrsToList (
        name: appliance: "${name}\t${appliance.lan.ip}\trouteros"
      ) self.inventory.appliances
    )
  );

  networkProbe = pkgs.writeShellApplication {
    name = "janus-network-probe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dnsutils
      pkgs.gawk
      pkgs.iproute2
      pkgs.iputils
    ];
    text = builtins.readFile ./network-probe.sh;
  };
in
{
  services.prometheus.exporters.smokeping = {
    enable = true;
    port = config.monitoring.exporters.smokeping;
    hosts = [ ];
    pingInterval = "1s";
    extraFlags = [ "--config.file=${smokepingConfig}" ];
  };

  # clan-core disables networkd-wait-online, so network-online.target precedes the WAN lease.
  systemd.services.router-wan-online = {
    description = "Wait for Janus WAN interface";
    after = [ "systemd-networkd.service" ];
    requires = [ "systemd-networkd.service" ];
    # With the WAN down, rerunning on switch would stall it a minute, then fail it.
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Capped at a minute; a prober started without a route fires LatencyProberSilent.
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --interface=${self.inventory.router.interfaces.wan}:routable --timeout=60";
    };
  };

  # A pinger whose first ping finds no route never pings again.
  systemd.services.prometheus-smokeping-exporter = {
    after = [ "router-wan-online.service" ];
    wants = [ "router-wan-online.service" ];
  };

  systemd.services.janus-network-probe = {
    description = "Probe Janus network reachability and DNS health";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe networkProbe} ${probeTargets} ${config.monitoring.textfileDirectory}/janus-network-probe.prom";
    };
  };

  systemd.timers.janus-network-probe = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "1m";
      AccuracySec = "10s";
      Persistent = true;
    };
  };
}
