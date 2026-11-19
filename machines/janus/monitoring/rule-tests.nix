# The rules on a small test network, so the cases don't change with the real cabling.
let
  cable = port: to: toPort: {
    appliance = "switch";
    inherit port to toPort;
  };

  network = import ./network.nix {
    router.machine = "janus";
    machines.laptop.tags = [ "portable" ];
    appliances = {
      switch = { };
      ap = { };
    };
    lan.cables = [
      (cable "sfp-sfpplus1" "server" null)
      (cable "sfp-sfpplus2" "nas" null)
      (cable "ether1" "ap" "ether1")
      (cable "ether2" "laptop" null)
      (cable "ether3" "desktop" null)
      (cable "ether4" "printer" null)
    ];
  };

  noAlert = alertname: time: {
    inherit alertname;
    eval_time = time;
    exp_alerts = [ ];
  };

  firing = alertname: time: alerts: {
    inherit alertname;
    eval_time = time;
    exp_alerts = alerts;
  };

  internetDown = {
    exp_labels = {
      instance = "janus";
      severity = "warning";
    };
    exp_annotations = {
      summary = "The internet connection is down";
      description = "The ISP gateway or every internet probe has stopped answering; check the modem and the WAN link.";
    };
  };

  dnsFailing = {
    exp_labels = {
      instance = "janus";
      severity = "critical";
    };
    exp_annotations = {
      summary = "The LAN's DNS resolver is failing";
      description = "Unbound is down or can't resolve names while the internet is up; see `systemctl status unbound` on janus.";
    };
  };
in
{
  rules = import ./rules.nix network;

  tests = [
    {
      name = "the internet is down once every internet probe fails, not while one still answers";
      interval = "1m";
      input_series = [
        {
          series = ''janus_network_probe_up{instance="janus", target="wan_gateway", group="wan"}'';
          values = "1x30";
        }
        {
          series = ''janus_network_probe_up{instance="janus", target="cloudflare_dns", group="internet"}'';
          values = "1x10 0x20";
        }
        {
          series = ''janus_network_probe_up{instance="janus", target="google_dns", group="internet"}'';
          values = "1x20 0x10";
        }
      ];
      alert_rule_test = [
        (noAlert "InternetDown" "20m")
        (noAlert "InternetDown" "25m")
        (firing "InternetDown" "27m" [ internetDown ])
      ];
    }

    {
      name = "the internet is down once the ISP gateway stops answering";
      interval = "1m";
      input_series = [
        {
          series = ''janus_network_probe_up{instance="janus", target="wan_gateway", group="wan"}'';
          values = "1x10 0x10";
        }
      ];
      alert_rule_test = [
        (noAlert "InternetDown" "15m")
        (firing "InternetDown" "17m" [ internetDown ])
      ];
    }

    {
      name = "losing 5% of the pings stays quiet; losing a quarter alerts once the ten-minute average has been over 10% for 15 minutes";
      interval = "1m";
      input_series = [
        {
          series = ''smokeping_requests_total{instance="janus", target="cloudflare_dns", group="internet"}'';
          values = "0+60x45";
        }
        {
          # 57 of each minute's 60 pings answered for 20 minutes, then 45.
          series = ''smokeping_response_duration_seconds_count{instance="janus", target="cloudflare_dns", group="internet"}'';
          values = "0+57x20 1185+45x24";
        }
      ];
      alert_rule_test = [
        (noAlert "InternetPacketLoss" "20m")
        (noAlert "InternetPacketLoss" "37m")
        (firing "InternetPacketLoss" "39m" [
          {
            exp_labels = {
              instance = "janus";
              severity = "warning";
            };
            exp_annotations = {
              summary = "The internet connection is losing packets";
              description = "25% of pings to internet hosts get no answer.";
            };
          }
        ])
      ];
    }

    {
      name = "pings lost while the ISP gateway is down are the outage, not packet loss";
      interval = "1m";
      input_series = [
        {
          series = ''janus_network_probe_up{instance="janus", target="wan_gateway", group="wan"}'';
          values = "1x10 0x20";
        }
        {
          series = ''smokeping_requests_total{instance="janus", target="cloudflare_dns", group="internet"}'';
          values = "0+60x30";
        }
        {
          series = ''smokeping_response_duration_seconds_count{instance="janus", target="cloudflare_dns", group="internet"}'';
          values = "0+60x10 600x20";
        }
      ];
      alert_rule_test = [ (noAlert "InternetPacketLoss" "30m") ];
    }

    {
      name = "DNS that fails while the internet is up alerts";
      interval = "1m";
      input_series = [
        {
          series = ''janus_network_probe_up{instance="janus", target="cloudflare_dns", group="internet"}'';
          values = "1x10";
        }
        {
          series = ''janus_dns_probe_up{instance="janus", query="google.com", status="SERVFAIL"}'';
          values = "0x10";
        }
      ];
      alert_rule_test = [
        (noAlert "DnsFailing" "4m")
        (firing "DnsFailing" "6m" [ dnsFailing ])
      ];
    }

    {
      name = "DNS that fails while the ISP gateway is down stays quiet, until unbound itself stops";
      interval = "1m";
      input_series = [
        {
          series = ''janus_network_probe_up{instance="janus", target="wan_gateway", group="wan"}'';
          values = "0x30";
        }
        {
          series = ''janus_dns_probe_up{instance="janus", query="google.com", status="SERVFAIL"}'';
          values = "0x30";
        }
        {
          series = ''node_systemd_unit_state{instance="janus", name="unbound.service", state="active"}'';
          values = "1x20 0x10";
        }
      ];
      alert_rule_test = [
        (noAlert "DnsFailing" "20m")
        (firing "DnsFailing" "27m" [ dnsFailing ])
      ];
    }

    {
      name = "DHCP and the firewall alert after 3 minutes inactive, not for a restart";
      interval = "1m";
      input_series = [
        {
          series = ''node_systemd_unit_state{instance="janus", name="kea-dhcp4-server.service", state="active"}'';
          values = "1x5 0x2 1x10 0x10";
        }
        {
          series = ''node_systemd_unit_state{instance="janus", name="nftables.service", state="active"}'';
          values = "1x5 0x2 1x10 0x10";
        }
      ];
      alert_rule_test = [
        (noAlert "DhcpDown" "8m")
        (noAlert "FirewallDown" "8m")
        (firing "DhcpDown" "24m" [
          {
            exp_labels = {
              instance = "janus";
              name = "kea-dhcp4-server.service";
              state = "active";
              severity = "critical";
            };
            exp_annotations = {
              summary = "The LAN's DHCP server is down";
              description = "New devices can't join the network; see `systemctl status kea-dhcp4-server` on janus.";
            };
          }
        ])
        (firing "FirewallDown" "24m" [
          {
            exp_labels = {
              instance = "janus";
              name = "nftables.service";
              state = "active";
              severity = "critical";
            };
            exp_annotations = {
              summary = "The router's firewall is not loaded";
              description = "nftables.service is inactive on janus; see its journal.";
            };
          }
        ])
      ];
    }

    {
      name = "a pool 95% leased for half an hour alerts once, not again for its subnet's totals; one 85% leased does not";
      interval = "5m";
      input_series = [
        {
          series = ''kea_dhcp4_addresses_assigned_total{instance="janus", subnet="10.10.0.0/24", subnet_id="10", pool="10.10.0.100-10.10.0.199"}'';
          values = "95x12";
        }
        {
          series = ''kea_dhcp4_addresses_total{instance="janus", subnet="10.10.0.0/24", subnet_id="10", pool="10.10.0.100-10.10.0.199"}'';
          values = "100x12";
        }
        {
          series = ''kea_dhcp4_addresses_assigned_total{instance="janus", subnet="10.10.0.0/24", subnet_id="10"}'';
          values = "95x12";
        }
        {
          series = ''kea_dhcp4_addresses_total{instance="janus", subnet="10.10.0.0/24", subnet_id="10"}'';
          values = "100x12";
        }
        {
          series = ''kea_dhcp4_addresses_assigned_total{instance="janus", subnet="10.30.0.0/24", subnet_id="30", pool="10.30.0.100-10.30.0.199"}'';
          values = "85x12";
        }
        {
          series = ''kea_dhcp4_addresses_total{instance="janus", subnet="10.30.0.0/24", subnet_id="30", pool="10.30.0.100-10.30.0.199"}'';
          values = "100x12";
        }
      ];
      alert_rule_test = [
        (noAlert "DhcpPoolExhausted" "29m")
        (firing "DhcpPoolExhausted" "31m" [
          {
            exp_labels = {
              instance = "janus";
              subnet = "10.10.0.0/24";
              subnet_id = "10";
              pool = "10.10.0.100-10.10.0.199";
              severity = "warning";
            };
            exp_annotations = {
              summary = "The DHCP pool for 10.10.0.0/24 is nearly used up";
              description = "95% of 10.10.0.100-10.10.0.199 is leased.";
            };
          }
        ])
      ];
    }

    {
      name = "a clock whose maximum error has been over a second for half an hour is unsynchronised; one at 0.9 s is not";
      interval = "1m";
      input_series = [
        {
          # 16 s is chrony's mark of an unsynchronised clock.
          series = ''node_timex_maxerror_seconds{instance="janus"}'';
          values = "0.9x10 1.5x10 16x30";
        }
      ];
      alert_rule_test = [
        (noAlert "ClockUnsynchronised" "40m")
        (firing "ClockUnsynchronised" "42m" [
          {
            exp_labels = {
              instance = "janus";
              severity = "warning";
            };
            exp_annotations = {
              summary = "The router's clock is unsynchronised";
              description = "Its maximum error is 16s, and the switches and access points take their time from it; see `chronyc sources` on janus.";
            };
          }
        ])
      ];
    }

    {
      name = "an unsynchronised clock while the ISP gateway is down stays quiet";
      interval = "1m";
      input_series = [
        {
          series = ''janus_network_probe_up{instance="janus", target="wan_gateway", group="wan"}'';
          values = "0x40";
        }
        {
          series = ''node_timex_maxerror_seconds{instance="janus"}'';
          values = "16x40";
        }
      ];
      alert_rule_test = [ (noAlert "ClockUnsynchronised" "35m") ];
    }

    {
      name = "an appliance that stops answering pings for 5 minutes is down, one that misses a few is not";
      interval = "1m";
      input_series = [
        {
          series = ''janus_network_probe_up{instance="janus", target="switch", address="10.99.0.2", group="routeros"}'';
          values = "1x5 0x15";
        }
        {
          series = ''janus_network_probe_up{instance="janus", target="ap", address="10.99.0.5", group="routeros"}'';
          values = "1x5 0x2 1x12";
        }
      ];
      alert_rule_test = [
        (noAlert "RouterOSDeviceDown" "10m")
        (firing "RouterOSDeviceDown" "12m" [
          {
            exp_labels = {
              instance = "janus";
              target = "switch";
              address = "10.99.0.2";
              group = "routeros";
              severity = "warning";
            };
            exp_annotations = {
              summary = "switch is unreachable";
              description = "The router can't ping switch at 10.99.0.2; check its power and uplink.";
            };
          }
        ])
      ];
    }

    {
      name = "errors at either end of a cable, in either direction, alert after 15 minutes; a few errors, or errors where the laptop docks, do not";
      interval = "1m";
      input_series =
        let
          counter = direction: name: interface: values: {
            series = ''mikrotik_interface_${direction}_error{instance="janus", job="mikrotik", name="${name}", interface="${interface}"}'';
            inherit values;
          };
          none = "0x30";
          twoPerSecond = "0+120x30";
          threePerMinute = "0+3x30";
          onePerFiveMinutes = "0x4 1x4 2x4 3x4 4x4 5x4 6x4";
        in
        [
          (counter "rx" "switch" "sfp-sfpplus1" twoPerSecond)
          (counter "tx" "switch" "sfp-sfpplus1" none)
          (counter "rx" "ap" "ether1" none)
          (counter "tx" "ap" "ether1" twoPerSecond)
          # Ports that report one direction only.
          (counter "rx" "switch" "sfp-sfpplus2" threePerMinute)
          (counter "tx" "switch" "ether4" twoPerSecond)
          (counter "rx" "switch" "ether3" onePerFiveMinutes)
          (counter "tx" "switch" "ether3" none)
          (counter "rx" "switch" "ether2" twoPerSecond)
          (counter "tx" "switch" "ether2" none)
        ];
      alert_rule_test =
        let
          linkErrors = name: interface: rate: {
            exp_labels = {
              instance = "janus";
              inherit name interface;
              severity = "warning";
            };
            exp_annotations = {
              summary = "${name} ${interface} has link errors";
              description = "${rate} errors/s on a cabled port; check the cable, transceiver and the port at its other end.";
            };
          };
        in
        [
          (noAlert "RouterOSLinkErrors" "15m")
          (firing "RouterOSLinkErrors" "22m" [
            (linkErrors "switch" "sfp-sfpplus1" "2.00")
            (linkErrors "ap" "ether1" "2.00")
            (linkErrors "switch" "sfp-sfpplus2" "0.05")
            (linkErrors "switch" "ether4" "2.00")
          ])
        ];
    }

    {
      name = "cables linked below their port's speed for an hour alert at their near end; ports at full speed or down do not";
      interval = "5m";
      input_series =
        let
          port = name: interface: rate: status: [
            {
              series = ''mikrotik_monitor_rate{instance="janus", job="mikrotik", name="${name}", interface="${interface}"}'';
              values = "${rate}x15";
            }
            {
              series = ''mikrotik_monitor_status{instance="janus", job="mikrotik", name="${name}", interface="${interface}"}'';
              values = "${status}x15";
            }
          ];
        in
        port "switch" "sfp-sfpplus1" "1000" "1"
        ++ port "switch" "sfp-sfpplus2" "10000" "1"
        ++ port "switch" "ether1" "100" "1"
        ++ port "ap" "ether1" "100" "1"
        ++ port "switch" "ether3" "1000" "1"
        ++ port "switch" "ether4" "0" "0";
      alert_rule_test = [
        (noAlert "RouterOSLinkSlow" "55m")
        (firing "RouterOSLinkSlow" "65m" [
          {
            exp_labels = {
              instance = "janus";
              job = "mikrotik";
              name = "switch";
              interface = "sfp-sfpplus1";
              severity = "warning";
            };
            exp_annotations = {
              summary = "switch sfp-sfpplus1 links at only 1000 Mb/s";
              description = "The cable on this port negotiated below the port's speed; reseat or replace it.";
            };
          }
          {
            exp_labels = {
              instance = "janus";
              job = "mikrotik";
              name = "switch";
              interface = "ether1";
              severity = "warning";
            };
            exp_annotations = {
              summary = "switch ether1 links at only 100 Mb/s";
              description = "The cable on this port negotiated below the port's speed; reseat or replace it.";
            };
          }
        ])
      ];
    }

    {
      name = "an appliance whose hottest sensor stays over 85°C for 15 minutes is too hot, one at 80°C is not";
      interval = "1m";
      input_series = [
        {
          series = ''janus_routeros_temperature_celsius{instance="janus", name="switch", sensor="cpu-temperature"}'';
          values = "90x20";
        }
        {
          series = ''janus_routeros_temperature_celsius{instance="janus", name="switch", sensor="sfp-temperature"}'';
          values = "50x20";
        }
        {
          series = ''janus_routeros_temperature_celsius{instance="janus", name="ap", sensor="cpu-temperature"}'';
          values = "80x20";
        }
      ];
      alert_rule_test = [
        (noAlert "RouterOSTooHot" "14m")
        (firing "RouterOSTooHot" "16m" [
          {
            exp_labels = {
              instance = "janus";
              name = "switch";
              severity = "warning";
            };
            exp_annotations = {
              summary = "switch is running hot";
              description = "Its hottest sensor reads 90°C; check its airflow and PoE load.";
            };
          }
        ])
      ];
    }

    {
      name = "an appliance that answers pings but fails either of its API scrapes for half an hour alerts";
      interval = "1m";
      input_series = [
        # The exporter's scrape of the switch fails.
        {
          series = ''janus_network_probe_up{instance="janus", target="switch", group="routeros"}'';
          values = "1x40";
        }
        {
          series = ''mikrotik_scrape_collector_success{instance="janus", job="mikrotik", device="switch", collector="interface"}'';
          values = "0x40";
        }
        {
          series = ''janus_routeros_health_scrape_success{instance="janus", name="switch"}'';
          values = "1x40";
        }
        # The health scrape of the access point fails.
        {
          series = ''janus_network_probe_up{instance="janus", target="ap", group="routeros"}'';
          values = "1x40";
        }
        {
          series = ''mikrotik_scrape_collector_success{instance="janus", job="mikrotik", device="ap", collector="interface"}'';
          values = "1x40";
        }
        {
          series = ''janus_routeros_health_scrape_success{instance="janus", name="ap"}'';
          values = "0x40";
        }
      ];
      alert_rule_test = [
        (noAlert "RouterOSMetricsFailing" "29m")
        (firing "RouterOSMetricsFailing" "31m" [
          {
            exp_labels = {
              instance = "janus";
              name = "switch";
              severity = "warning";
            };
            exp_annotations = {
              summary = "Metrics from switch are failing";
              description = "switch answers pings but not its API; check the prometheus API user and the API service on it.";
            };
          }
          {
            exp_labels = {
              instance = "janus";
              name = "ap";
              severity = "warning";
            };
            exp_annotations = {
              summary = "Metrics from ap are failing";
              description = "ap answers pings but not its API; check the prometheus API user and the API service on it.";
            };
          }
        ])
      ];
    }

    {
      name = "an appliance that is down does not also alert for its failing scrapes";
      interval = "1m";
      input_series = [
        {
          series = ''janus_network_probe_up{instance="janus", target="switch", group="routeros"}'';
          values = "0x40";
        }
        {
          series = ''mikrotik_scrape_collector_success{instance="janus", job="mikrotik", device="switch", collector="interface"}'';
          values = "0x40";
        }
        {
          series = ''janus_routeros_health_scrape_success{instance="janus", name="switch"}'';
          values = "0x40";
        }
      ];
      alert_rule_test = [ (noAlert "RouterOSMetricsFailing" "31m") ];
    }

    {
      name = "an appliance that has rolled back a net-apply alerts at once, until the next net-apply removes its marker";
      interval = "1m";
      input_series = [
        {
          series = ''janus_routeros_rolled_back{instance="janus", name="switch"}'';
          values = "0x30";
        }
        {
          series = ''janus_routeros_rolled_back{instance="janus", name="ap"}'';
          values = "0x9 1x10 0x10";
        }
      ];
      alert_rule_test = [
        (noAlert "RouterOSRolledBack" "9m")
        (firing "RouterOSRolledBack" "10m" [
          {
            exp_labels = {
              instance = "janus";
              name = "ap";
              severity = "warning";
            };
            exp_annotations = {
              summary = "ap rolled back a net-apply";
              description = "The net-apply that armed ap was not confirmed, so it restored, or tried to restore, the configuration it had before that apply; the next net-apply says which, plans that apply's changes again and clears this.";
            };
          }
        ])
        (noAlert "RouterOSRolledBack" "21m")
      ];
    }
  ];
}
