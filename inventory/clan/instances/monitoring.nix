{
  monitoring = {
    module = {
      name = "@adeci/monitoring";
      input = "self";
    };
    roles = {
      agent = {
        tags = [ "adeci-net" ];
        machines.janus.settings = {
          extraCollectors = [ "conntrack" ];
          extraLabels.role = "router";
          extraScrapeTargets = [
            {
              job = "kea-dhcp4";
              target = "127.0.0.1:9547";
            }
          ];
        };
      };
      server.machines.sequoia.settings = {
        host = "sequoia.cymric-daggertooth.ts.net";
        grafana.enable = true;
        retentionDays = 30;
        loki.retentionHours = 168;
      };
    };
  };
}
