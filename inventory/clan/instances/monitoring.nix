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
