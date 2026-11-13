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
    listenAddress = "127.0.0.1";
    port = 9374;
    hosts = [ ];
    pingInterval = "1s";
    extraFlags = [ "--config.file=${smokepingConfig}" ];
  };

  monitoring.scrapeTargets.smokeping =
    let
      inherit (config.services.prometheus.exporters) smokeping;
    in
    "${smokeping.listenAddress}:${toString smokeping.port}";

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
