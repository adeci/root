{
  lib,
  pkgs,
  self,
  ...
}:
let
  routerosTargets = lib.mapAttrsToList (name: device: {
    inherit name;
    address = device.host;
  }) self.resources.routeros;

  smokepingConfig = pkgs.writeText "janus-smokeping.yml" ''
    ---
    targets:
      - hosts:
          - 1.1.1.1
        interval: 1s
        network: ip4
        protocol: icmp
        labels:
          group: internet
          target: cloudflare_dns
      - hosts:
          - 8.8.8.8
        interval: 1s
        network: ip4
        protocol: icmp
        labels:
          group: internet
          target: google_dns
  '';

  targetFile = pkgs.writeText "janus-network-probe-targets.tsv" (
    lib.concatLines (
      [
        "cloudflare_dns\t1.1.1.1\tinternet"
        "google_dns\t8.8.8.8\tinternet"
      ]
      ++ map (target: "${target.name}\t${target.address}\trouteros") routerosTargets
    )
  );

  probeCommand = pkgs.writeShellApplication {
    name = "janus-network-probe";
    runtimeInputs = with pkgs; [
      coreutils
      dnsutils
      gawk
      gnused
      iproute2
      iputils
    ];
    text = # bash
      ''
        out_dir=/var/lib/alloy/textfile
        install -d -m 0755 "$out_dir"
        rm -f "$out_dir/janus-network-observe.prom"
        tmp=$(mktemp "$out_dir/janus-network-probe.prom.XXXXXX")
        trap 'rm -f "$tmp"' EXIT

        emit() {
          printf '%s\n' "$*" >> "$tmp"
        }

        emit '# HELP janus_network_probe_up Whether a Janus network probe succeeded.'
        emit '# TYPE janus_network_probe_up gauge'
        emit '# HELP janus_network_probe_latency_seconds Probe round-trip latency in seconds.'
        emit '# TYPE janus_network_probe_latency_seconds gauge'
        emit '# HELP janus_network_probe_packet_loss_ratio Probe packet loss ratio from 0 to 1.'
        emit '# TYPE janus_network_probe_packet_loss_ratio gauge'
        emit '# HELP janus_dns_probe_up Whether the local Unbound DNS probe succeeded.'
        emit '# TYPE janus_dns_probe_up gauge'
        emit '# HELP janus_dns_probe_latency_seconds Local Unbound DNS query latency in seconds.'
        emit '# TYPE janus_dns_probe_latency_seconds gauge'

        probe_ping() {
          local name="$1"
          local address="$2"
          local group="$3"
          local output up loss latency

          if output=$(ping -n -c 3 -W 1 -q "$address" 2>&1); then
            up=1
          else
            up=0
          fi

          loss=$(printf '%s\n' "$output" | awk -F', ' '/packet loss/ { for (i = 1; i <= NF; i++) if ($i ~ /packet loss/) { gsub(/% packet loss/, "", $i); print $i / 100; exit } }')
          latency=$(printf '%s\n' "$output" | awk -F/ '/rtt|round-trip/ { print $5 / 1000; exit }')

          emit "janus_network_probe_up{target=\"$name\",address=\"$address\",group=\"$group\"} $up"
          emit "janus_network_probe_packet_loss_ratio{target=\"$name\",address=\"$address\",group=\"$group\"} ''${loss:-1}"
          if [[ -n "''${latency:-}" ]]; then
            emit "janus_network_probe_latency_seconds{target=\"$name\",address=\"$address\",group=\"$group\"} $latency"
          fi
        }

        default_gateway=$(ip -4 route show default | awk 'NR == 1 { print $3 }')
        if [[ -n "$default_gateway" ]]; then
          probe_ping "wan_gateway" "$default_gateway" "wan"
        else
          emit 'janus_network_probe_up{target="wan_gateway",address="unknown",group="wan"} 0'
          emit 'janus_network_probe_packet_loss_ratio{target="wan_gateway",address="unknown",group="wan"} 1'
        fi

        while IFS=$'\t' read -r name address group; do
          probe_ping "$name" "$address" "$group"
        done < ${targetFile}

        dns_output=$(dig @127.0.0.1 google.com A +time=2 +tries=1 +stats 2>&1 || true)
        dns_status=$(printf '%s\n' "$dns_output" | awk '/status:/ { gsub(",", "", $6); print $6; exit }')
        dns_ms=$(printf '%s\n' "$dns_output" | awk '/Query time:/ { print $4; exit }')
        dns_up=0
        if [[ "''${dns_status:-}" == "NOERROR" && -n "''${dns_ms:-}" ]]; then
          dns_up=1
          emit "janus_dns_probe_latency_seconds{server=\"127.0.0.1\",query=\"google.com\",type=\"A\"} $(awk -v ms="$dns_ms" 'BEGIN { print ms / 1000 }')"
        fi
        emit "janus_dns_probe_up{server=\"127.0.0.1\",query=\"google.com\",type=\"A\",status=\"''${dns_status:-unknown}\"} $dns_up"

        chmod 0644 "$tmp"
        mv "$tmp" "$out_dir/janus-network-probe.prom"
        trap - EXIT
      '';
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

  systemd.services.janus-network-probe = {
    description = "Probe Janus network reachability and DNS health";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe probeCommand;
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
