let
  minimalJournal = {
    journal = {
      mode = "explicit";
      include = [
        "alloy"
        "sshd"
        "tailscaled"
        "tailscaled-autoconnect"
        "tailscaled-set"
      ];
    };
  };
in
{
  monitoring = {
    module = {
      name = "@adeci/monitoring";
      input = "self";
    };
    roles = {
      agent = {
        tags = [ "adeci-net" ];
        machines = {
          aegis.settings = minimalJournal;
          atropos.settings = minimalJournal;
          clotho.settings = minimalJournal;
          kasha.settings = minimalJournal;
          lachesis.settings = minimalJournal;
          modus.settings = minimalJournal;
          praxis.settings = minimalJournal;
          proteus.settings = minimalJournal;

          janus.settings = {
            extraCollectors = [ "conntrack" ];
            extraLabels.role = "router";
            extraScrapeTargets = [
              {
                job = "kea-dhcp4";
                target = "127.0.0.1:9547";
              }
              {
                job = "unbound";
                target = "127.0.0.1:9167";
              }
              {
                job = "smokeping";
                target = "127.0.0.1:9374";
              }
              {
                job = "mikrotik";
                target = "127.0.0.1:9436";
              }
              {
                job = "mikrotik-poe";
                target = "127.0.0.1:9437";
              }
            ];
          };

          leviathan.settings.extraScrapeTargets = [
            {
              job = "dcgm";
              target = "127.0.0.1:9400";
            }
          ];

          sequoia.settings.extraScrapeTargets = [
            {
              job = "litellm";
              target = "127.0.0.1:4000";
            }
          ];
        };
      };
      server.machines.sequoia.settings = {
        host = "sequoia.cymric-daggertooth.ts.net";
        grafana.enable = true;
        retentionDays = 30;
        loki.retentionHours = 168;
        alertDelivery.ntfy.enable = true;
      };
    };
  };
}
