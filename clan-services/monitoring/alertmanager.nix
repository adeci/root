{
  lib,
  webhookUrl,
  timeZone,
  quietHours,
}:
let
  # Alertmanager times can't wrap past midnight: split an overnight window in two.
  quietTimes =
    if quietHours.start < quietHours.end then
      [
        {
          start_time = quietHours.start;
          end_time = quietHours.end;
        }
      ]
    else
      [
        {
          start_time = quietHours.start;
          end_time = "24:00";
        }
        {
          start_time = "00:00";
          end_time = quietHours.end;
        }
      ];

  # Child routes don't inherit mute times.
  quietMute = lib.optionalAttrs (quietHours != null) { mute_time_intervals = [ "quiet-hours" ]; };

  warningRoute = {
    matchers = [ ''severity="warning"'' ];
    repeat_interval = "24h";
    # One-off news, such as a new device: notify once.
    routes = [
      (
        {
          matchers = [ ''send_resolved="false"'' ];
          receiver = "ntfy-once";
        }
        // quietMute
      )
    ];
  }
  // quietMute;
in
{
  route = {
    receiver = "ntfy";
    # The bridge notifies per alert anyway; grouping would only repeat them.
    group_by = [ "..." ];
    group_wait = "30s";
    group_interval = "5m";
    repeat_interval = "12h";
    routes = [ warningRoute ];
  };

  inhibit_rules = [
    {
      # A machine that is down can't vouch for anything else about itself.
      source_matchers = [ ''alertname="HostDown"'' ];
      target_matchers = [ ''alertname!="HostDown"'' ];
      equal = [ "instance" ];
    }
    {
      # Router down = site offline: one alert, not one per machine behind it.
      source_matchers = [
        ''alertname="HostDown"''
        ''role="router"''
      ];
      target_matchers = [
        ''alertname="HostDown"''
        ''role!="router"''
      ];
    }
    {
      # Tunnel down: one alert, not one per name.
      source_matchers = [ ''alertname="TunnelDown"'' ];
      target_matchers = [ ''alertname="PublicNameDown"'' ];
      equal = [ "instance" ];
    }
    {
      source_matchers = [ ''severity="critical"'' ];
      target_matchers = [ ''severity="warning"'' ];
      equal = [
        "alertname"
        "instance"
        "mountpoint"
      ];
    }
  ];

  receivers = [
    {
      name = "ntfy";
      webhook_configs = [
        {
          url = webhookUrl;
          send_resolved = true;
        }
      ];
    }
    {
      name = "ntfy-once";
      webhook_configs = [
        {
          url = webhookUrl;
          send_resolved = false;
        }
      ];
    }
  ];

  time_intervals = lib.optional (quietHours != null) {
    name = "quiet-hours";
    time_intervals = [
      {
        times = quietTimes;
        location = timeZone;
      }
    ];
  };
}
