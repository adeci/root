{
  lib,
  machineName,
  serverUrl,
  scrapeInterval,
  extraCollectors,
  extraLabels,
  scrapeTargets,
  textfileDirectory,
  journalUnits,
  journalRelabelRules,
}:
let
  collectors = [
    "cpu"
    "meminfo"
    "filesystem"
    "diskstats"
    "netdev"
    "netclass"
    "loadavg"
    "stat"
    "uname"
    "systemd"
    "pressure"
    "hwmon"
    "edac"
    "textfile"
  ]
  ++ extraCollectors;
  quotedCollectors = lib.concatMapStringsSep ", " (collector: "\"${collector}\"") collectors;

  # Alloy component labels must match [a-zA-Z_][a-zA-Z0-9_]*.
  scrapeTargetBlock = job: address: ''
    prometheus.scrape "target_${builtins.replaceStrings [ "-" ] [ "_" ] job}" {
      targets = [{
        __address__ = "${address}",
        instance    = "${machineName}",
        job         = "${job}",
      }]
      honor_labels    = true
      forward_to      = [prometheus.remote_write.server.receiver]
      scrape_interval = "${scrapeInterval}"
    }
  '';
  scrapeTargetBlocks = lib.concatStringsSep "\n" (lib.mapAttrsToList scrapeTargetBlock scrapeTargets);

  externalLabelPairs = lib.mapAttrsToList (
    name: value: "    \"${name}\" = \"${value}\","
  ) extraLabels;
  externalLabelsBlock = lib.optionalString (extraLabels != { }) ''
    external_labels = {
    ${lib.concatStringsSep "\n" externalLabelPairs}
    }
  '';

  journalKeepRule = lib.optionalString (journalUnits != null && journalUnits != [ ]) ''
    rule {
      action = "keep"
      source_labels = ["__journal__systemd_unit"]
      regex = ${builtins.toJSON "^(${lib.concatMapStringsSep "|" lib.escapeRegex journalUnits})$"}
    }
  '';
in
''
  prometheus.exporter.unix "local_system" {
    set_collectors = [${quotedCollectors}]

    textfile {
      directory = "${textfileDirectory}"
    }
  }

  // The server's alerts expect node metrics under the machine name, whatever the hostname.
  discovery.relabel "node" {
    targets = prometheus.exporter.unix.local_system.targets

    rule {
      target_label = "instance"
      replacement  = "${machineName}"
    }
  }

  prometheus.scrape "node" {
    targets         = discovery.relabel.node.output
    forward_to      = [prometheus.remote_write.server.receiver]
    scrape_interval = "${scrapeInterval}"
  }

  // Alloy's own metrics, under the machine name like the node metrics.
  prometheus.scrape "alloy_self" {
    targets = [{
      __address__ = "127.0.0.1:12345",
      instance    = "${machineName}",
      job         = "alloy",
    }]
    honor_labels    = true
    forward_to      = [prometheus.remote_write.server.receiver]
    scrape_interval = "${scrapeInterval}"
  }

  ${scrapeTargetBlocks}

  prometheus.remote_write "server" {
    ${externalLabelsBlock}
    endpoint {
      url = "${serverUrl}/prometheus/api/v1/write"
      basic_auth {
        username      = "alloy"
        password_file = sys.env("CREDENTIALS_DIRECTORY") + "/prometheus-auth-password"
      }
    }
  }

  loki.source.journal "systemd" {
    forward_to    = [loki.write.server.receiver]
    relabel_rules = loki.relabel.journal.rules
    labels        = {
      job = "systemd-journal",
    }
  }

  loki.relabel "journal" {
    ${journalKeepRule}
    rule {
      source_labels = ["__journal__hostname"]
      target_label  = "instance"
    }
    rule {
      source_labels = ["__journal__systemd_unit"]
      target_label  = "service_name"
    }
    rule {
      source_labels = ["__journal__transport"]
      target_label  = "transport"
    }
    rule {
      source_labels = ["__journal_priority_keyword"]
      target_label  = "level"
    }
    ${lib.concatStringsSep "\n" journalRelabelRules}
    forward_to = []
  }

  loki.write "server" {
    ${externalLabelsBlock}
    endpoint {
      url = "${serverUrl}/loki/loki/api/v1/push"
      basic_auth {
        username      = "alloy"
        password_file = sys.env("CREDENTIALS_DIRECTORY") + "/loki-auth-password"
      }
    }
  }
''
