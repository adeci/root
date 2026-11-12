# Alertmanager routing: every alert notifies through the ntfy bridge, warnings wait out the quiet hours.
{
  lib,
  webhookUrl,
  timeZone,
  quietHours,
}:
let
  # Alertmanager times can't wrap past midnight, so an evening-to-morning window is split in two.
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

  warningRoute = {
    matchers = [ ''severity="warning"'' ];
    repeat_interval = "24h";
  }
  // lib.optionalAttrs (quietHours != null) { mute_time_intervals = [ "quiet-hours" ]; };
in
{
  route = {
    receiver = "ntfy";
    # The bridge posts one notification per alert, so grouping alerts would only repeat them.
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
