{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  mainConfigPath = "/run/prometheus-mikrotik-exporter/config.yml";
  poeConfigPath = "/run/prometheus-mikrotik-poe-exporter/config.yml";

  mkDevices =
    devices:
    lib.mapAttrsToList (name: device: {
      inherit name;
      address = device.host;
      port = toString (device.port or 8728);
      user = "prometheus";
    }) devices;

  mainBaseConfig = pkgs.writeText "routeros-exporter-base.json" (
    builtins.toJSON {
      devices = mkDevices self.resources.routeros;
      features.monitor = true;
    }
  );

  poeBaseConfig = pkgs.writeText "routeros-poe-exporter-base.json" (
    builtins.toJSON {
      devices = mkDevices { inherit (self.resources.routeros) nexus; };
      features.poe = true;
    }
  );

  healthDevices = pkgs.writeText "routeros-health-devices.json" (
    builtins.toJSON (mkDevices self.resources.routeros)
  );

  routerosHealthProbe = pkgs.writeTextFile {
    name = "janus-routeros-health";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.python3}
      import json
      import os
      import socket
      import time
      from pathlib import Path

      DEVICES = json.loads(Path("${healthDevices}").read_text())
      PASSWORD = Path(os.environ["CREDENTIALS_DIRECTORY"] + "/routeros-password").read_text().strip()
      OUT = Path("/var/lib/alloy/textfile/janus-routeros-health.prom")

      def encode_length(length):
          if length < 0x80:
              return bytes([length])
          if length < 0x4000:
              return (length | 0x8000).to_bytes(2, "big")
          if length < 0x200000:
              return (length | 0xC00000).to_bytes(3, "big")
          if length < 0x10000000:
              return (length | 0xE0000000).to_bytes(4, "big")
          return b"\xf0" + length.to_bytes(4, "big")

      def decode_length(sock):
          first = sock.recv(1)
          if not first:
              raise EOFError("RouterOS API closed connection")
          byte = first[0]
          if byte & 0x80 == 0:
              return byte
          if byte & 0xC0 == 0x80:
              return int.from_bytes(bytes([byte & ~0xC0]) + sock.recv(1), "big")
          if byte & 0xE0 == 0xC0:
              return int.from_bytes(bytes([byte & ~0xE0]) + sock.recv(2), "big")
          if byte & 0xF0 == 0xE0:
              return int.from_bytes(bytes([byte & ~0xF0]) + sock.recv(3), "big")
          return int.from_bytes(sock.recv(4), "big")

      def send_sentence(sock, words):
          for word in words:
              data = word.encode()
              sock.sendall(encode_length(len(data)) + data)
          sock.sendall(b"\x00")

      def read_sentence(sock):
          words = []
          while True:
              length = decode_length(sock)
              if length == 0:
                  return words
              words.append(sock.recv(length).decode(errors="replace"))

      def read_until_done(sock):
          sentences = []
          while True:
              sentence = read_sentence(sock)
              sentences.append(sentence)
              if sentence and sentence[0] in ("!done", "!fatal"):
                  return sentences

      def sentence_attrs(sentence):
          attrs = {}
          for word in sentence[1:]:
              if word.startswith("="):
                  key, _, value = word[1:].partition("=")
                  attrs[key] = value
          return attrs

      def escape_label(value):
          return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')

      def labels(**pairs):
          return "{" + ",".join(f'{key}="{escape_label(value)}"' for key, value in pairs.items()) + "}"

      def emit_metric(lines, metric, value, **label_pairs):
          lines.append(f"{metric}{labels(**label_pairs)} {value}")

      def collect_device(device):
          started = time.monotonic()
          rows = []
          with socket.create_connection((device["address"], int(device.get("port", "8728"))), timeout=4) as sock:
              send_sentence(sock, ["/login", "=name=" + device["user"], "=password=" + PASSWORD])
              login = read_until_done(sock)
              if login[-1][0] != "!done":
                  raise RuntimeError("RouterOS API login failed")

              send_sentence(sock, ["/system/health/print"])
              for sentence in read_until_done(sock):
                  if sentence and sentence[0] == "!re":
                      rows.append(sentence_attrs(sentence))
                  elif sentence and sentence[0] in ("!trap", "!fatal"):
                      raise RuntimeError(sentence_attrs(sentence).get("message", sentence[0]))
          return rows, time.monotonic() - started

      metric_for_unit = {
          "C": "janus_routeros_temperature_celsius",
          "RPM": "janus_routeros_fan_speed_rpm",
          "V": "janus_routeros_voltage_volts",
          "A": "janus_routeros_current_amperes",
          "W": "janus_routeros_power_watts",
      }

      lines = [
          "# HELP janus_routeros_health_scrape_success Whether RouterOS /system/health API scrape succeeded.",
          "# TYPE janus_routeros_health_scrape_success gauge",
          "# HELP janus_routeros_health_scrape_duration_seconds RouterOS /system/health API scrape duration.",
          "# TYPE janus_routeros_health_scrape_duration_seconds gauge",
          "# HELP janus_routeros_temperature_celsius RouterOS health temperature sensors.",
          "# TYPE janus_routeros_temperature_celsius gauge",
          "# HELP janus_routeros_fan_speed_rpm RouterOS health fan speed sensors.",
          "# TYPE janus_routeros_fan_speed_rpm gauge",
          "# HELP janus_routeros_voltage_volts RouterOS health voltage sensors.",
          "# TYPE janus_routeros_voltage_volts gauge",
          "# HELP janus_routeros_current_amperes RouterOS health current sensors.",
          "# TYPE janus_routeros_current_amperes gauge",
          "# HELP janus_routeros_power_watts RouterOS health power sensors.",
          "# TYPE janus_routeros_power_watts gauge",
      ]

      for device in DEVICES:
          name = device["name"]
          address = device["address"]
          try:
              rows, duration = collect_device(device)
              emit_metric(lines, "janus_routeros_health_scrape_success", 1, name=name, address=address)
              emit_metric(lines, "janus_routeros_health_scrape_duration_seconds", f"{duration:.6f}", name=name, address=address)
              for row in rows:
                  metric = metric_for_unit.get(row.get("type", ""))
                  if not metric:
                      continue
                  try:
                      value = float(row["value"])
                  except (KeyError, ValueError):
                      continue
                  emit_metric(lines, metric, value, name=name, sensor=row.get("name", "unknown"))
          except Exception:
              emit_metric(lines, "janus_routeros_health_scrape_success", 0, name=name, address=address)

      tmp = OUT.with_suffix(".prom.tmp")
      tmp.write_text("\n".join(lines) + "\n")
      tmp.chmod(0o644)
      tmp.replace(OUT)
    '';
  };

  writeRuntimeConfig =
    baseConfig: configPath: # bash
    ''
      set -euo pipefail

      runtime_dir=$(dirname ${configPath})
      config_file=${configPath}
      password=$(tr -d '\n' < "$CREDENTIALS_DIRECTORY/routeros-password")
      tmp=$(mktemp "$runtime_dir/config.yml.XXXXXX")
      trap 'rm -f "$tmp"' EXIT

      jq --arg password "$password" \
        '.devices |= map(. + { password: $password })' \
        ${baseConfig} > "$tmp"
      chmod 0600 "$tmp"
      mv "$tmp" "$config_file"
      trap - EXIT
    '';
in
{
  clan.core.vars.generators.routeros-exporter.files.password.secret = true;

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
    path = [
      pkgs.coreutils
      pkgs.jq
    ];

    preStart = writeRuntimeConfig mainBaseConfig mainConfigPath;

    serviceConfig = {
      LoadCredential = [
        "routeros-password:${config.clan.core.vars.generators.routeros-exporter.files.password.path}"
      ];
      RuntimeDirectory = "prometheus-mikrotik-exporter";
      RuntimeDirectoryMode = "0700";
    };
  };

  systemd.services.prometheus-mikrotik-poe-exporter = {
    description = "Prometheus exporter for RouterOS PoE metrics";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = [
      pkgs.coreutils
      pkgs.jq
    ];

    preStart = writeRuntimeConfig poeBaseConfig poeConfigPath;

    serviceConfig = {
      DynamicUser = true;
      LoadCredential = [
        "routeros-password:${config.clan.core.vars.generators.routeros-exporter.files.password.path}"
      ];
      RuntimeDirectory = "prometheus-mikrotik-poe-exporter";
      RuntimeDirectoryMode = "0700";
      ExecStart = "${pkgs.prometheus-mikrotik-exporter}/bin/mikrotik-exporter -config-file=${poeConfigPath} -port=127.0.0.1:9437 -log-format=json -log-level=info";
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
      ExecStart = routerosHealthProbe;
      LoadCredential = [
        "routeros-password:${config.clan.core.vars.generators.routeros-exporter.files.password.path}"
      ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/alloy/textfile" ];
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
