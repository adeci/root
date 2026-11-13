{ ui, queries, ... }:
let
  unbound = ''${queries.router},job="unbound"'';

  rate = metric: "sum(rate(${metric}{${unbound}}[$__rate_interval])) or vector(0)";
  cacheHitRatio = ''
    (
      sum(rate(unbound_cache_hits_total{${unbound}}[$__rate_interval]))
      /
      clamp_min(
        sum(rate(unbound_cache_hits_total{${unbound}}[$__rate_interval]))
        + sum(rate(unbound_cache_misses_total{${unbound}}[$__rate_interval])),
        0.001
      )
    ) or vector(0)
  '';
  latency = quantile: ''
    (1000 * histogram_quantile(${quantile}, sum by (le) (rate(unbound_response_time_seconds_bucket{${unbound}}[$__rate_interval]))))
    or vector(0)
  '';
in
ui.row {
  title = "DNS";
  panels = [
    (ui.timeseries {
      title = "DNS Resolution";
      w = 8;
      h = 7;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target "1000 * janus_dns_probe_latency_seconds" "google.com A via 127.0.0.1")
      ];
    })
    (ui.stat {
      title = "DNS probe status";
      w = 4;
      h = 4;
      expr = "max(janus_dns_probe_up) or vector(0)";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      title = "Unbound status";
      w = 4;
      h = 4;
      expr = "max(unbound_up{${unbound}}) or vector(0)";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.timeseries {
      title = "Unbound Queries";
      w = 8;
      h = 7;
      unit = "ops";
      threshold = ui.thresholds.neutral;
      targets = [ (ui.target (rate "unbound_queries_total") "queries") ];
    })

    (ui.timeseries {
      title = "Cache Hit Ratio";
      w = 8;
      h = 7;
      unit = "percentunit";
      threshold = ui.thresholds.neutral;
      targets = [ (ui.target cacheHitRatio "hits / total") ];
    })
    (ui.timeseries {
      title = "RCODE Rates";
      w = 8;
      h = 7;
      unit = "ops";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target ''sum by (rcode) (rate(unbound_answer_rcodes_total{${unbound},rcode=~"NOERROR|NXDOMAIN|SERVFAIL"}[$__rate_interval])) or on() vector(0)'' "{{rcode}}")
      ];
    })
    (ui.timeseries {
      title = "Query Type Rates";
      w = 8;
      h = 7;
      unit = "ops";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target ''sum by (type) (rate(unbound_query_types_total{${unbound},type=~"A|AAAA|PTR|SRV"}[$__rate_interval])) or on() vector(0)'' "{{type}}")
      ];
    })

    (ui.timeseries {
      title = "Response Latency";
      w = 8;
      h = 7;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target (latency "0.50") "p50")
        (ui.target (latency "0.95") "p95")
      ];
    })
    (ui.timeseries {
      title = "Request List Pressure";
      w = 8;
      h = 7;
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "sum(unbound_request_list_current_user{${unbound}}) or vector(0)" "current user")
        (ui.target "sum(unbound_request_list_current_all{${unbound}}) or vector(0)" "current all")
        (ui.target (rate "unbound_request_list_exceeded_total") "dropped/s")
        (ui.target (rate "unbound_request_list_overwritten_total") "overwritten/s")
      ];
    })
    (ui.timeseries {
      title = "Unbound Memory";
      w = 8;
      h = 7;
      unit = "bytes";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "sum by (cache) (unbound_memory_caches_bytes{${unbound}}) or on() vector(0)" "cache {{cache}}")
        (ui.target "sum by (module) (unbound_memory_modules_bytes{${unbound}}) or on() vector(0)" "module {{module}}")
      ];
    })
  ];
}
