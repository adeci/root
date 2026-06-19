{
  lib,
  pkgs,
  self,
  ...
}:
let
  topology = import ./topology.nix { inherit lib self; };

  interfaceForTarget =
    target:
    if target == "wan" then
      topology.wan
    else if target == "tailscale" then
      "tailscale0"
    else
      forwardZones.${target}.interface;

  forwardZones = {
    trusted = {
      interface = topology.vlanInterface topology.vlans.trusted;
      description = "trusted clients; full routed access";
      allowAny = true;
      counter = "forward_accept_trusted";
    };
    iot = {
      interface = topology.vlanInterface topology.vlans.iot;
      description = "IoT clients; internet only";
      allow = [
        {
          target = "wan";
          counter = "forward_accept_iot_to_wan";
        }
      ];
    };
    guest = {
      interface = topology.vlanInterface topology.vlans.guest;
      description = "guest clients; internet only";
      allow = [
        {
          target = "wan";
          counter = "forward_accept_guest_to_wan";
        }
      ];
    };
    mgmt = {
      interface = "br-mgmt";
      description = "infrastructure management; no forwarding by default";
      allow = [ ];
    };
  };

  firewallCounters = [
    {
      name = "input_accept_established_related";
      chain = "input";
      action = "accept";
      zone = "any";
    }
    {
      name = "input_drop_invalid";
      chain = "input";
      action = "drop";
      zone = "any";
    }
    {
      name = "input_accept_loopback";
      chain = "input";
      action = "accept";
      zone = "loopback";
    }
    {
      name = "input_accept_icmp";
      chain = "input";
      action = "accept";
      zone = "any";
    }
    {
      name = "input_accept_dhcp_dns";
      chain = "input";
      action = "accept";
      zone = "local";
    }
    {
      name = "input_accept_tailscale_direct_udp";
      chain = "input";
      action = "accept";
      zone = "wan";
    }
    {
      name = "input_accept_tailnet_admin";
      chain = "input";
      action = "accept";
      zone = "tailscale";
    }
    {
      name = "input_accept_ssh_admin";
      chain = "input";
      action = "accept";
      zone = "admin";
    }
    {
      name = "input_drop_default";
      chain = "input";
      action = "drop";
      zone = "default";
    }
    {
      name = "forward_accept_established_related";
      chain = "forward";
      action = "accept";
      zone = "any";
    }
    {
      name = "forward_drop_invalid";
      chain = "forward";
      action = "drop";
      zone = "any";
    }
    {
      name = "forward_accept_tailscale_to_local";
      chain = "forward";
      action = "accept";
      zone = "tailscale";
    }
    {
      name = "forward_accept_trusted";
      chain = "forward";
      action = "accept";
      zone = "trusted";
    }
    {
      name = "forward_accept_iot_to_wan";
      chain = "forward";
      action = "accept";
      zone = "iot";
    }
    {
      name = "forward_accept_guest_to_wan";
      chain = "forward";
      action = "accept";
      zone = "guest";
    }
    {
      name = "forward_drop_default";
      chain = "forward";
      action = "drop";
      zone = "default";
    }
  ];

  counterObjects = lib.concatMapStringsSep "\n" (counter: ''
    counter ${counter.name} {
      packets 0 bytes 0
    }
  '') firewallCounters;

  counterMetadataFile = pkgs.writeText "janus-firewall-counter-metadata.json" (
    builtins.toJSON (
      map (
        counter:
        counter
        // {
          family = "inet";
          table = "filter";
        }
      ) firewallCounters
    )
  );

  firewallExporter = pkgs.writeTextFile {
    name = "janus-firewall-counters";
    destination = "/bin/janus-firewall-counters";
    executable = true;
    text = ''
      #!${pkgs.python3}/bin/python3
      import json
      import os
      import subprocess
      import tempfile

      NFT = "${pkgs.nftables}/bin/nft"
      METADATA_PATH = "${counterMetadataFile}"
      OUT_DIR = "/var/lib/alloy/textfile"
      OUT_PATH = os.path.join(OUT_DIR, "janus-firewall-counters.prom")


      def label_value(value):
          return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


      def metric_line(metric, labels, value):
          label_text = ",".join(f'{key}="{label_value(labels[key])}"' for key in sorted(labels))
          return f"{metric}{{{label_text}}} {int(value)}\n"


      def load_counters():
          ruleset = json.loads(subprocess.check_output([NFT, "-j", "list", "ruleset"], text=True))
          counters = {}
          for item in ruleset.get("nftables", []):
              counter = item.get("counter") if isinstance(item, dict) else None
              if counter is None:
                  continue
              key = (counter.get("family"), counter.get("table"), counter.get("name"))
              counters[key] = counter
          return counters


      def main():
          with open(METADATA_PATH, encoding="utf-8") as metadata_file:
              metadata = json.load(metadata_file)

          observed = load_counters()
          os.makedirs(OUT_DIR, mode=0o755, exist_ok=True)
          fd, tmp_path = tempfile.mkstemp(prefix="janus-firewall-counters.prom.", dir=OUT_DIR, text=True)
          try:
              with os.fdopen(fd, "w", encoding="utf-8") as output:
                  os.fchmod(output.fileno(), 0o644)
                  output.write("# HELP janus_firewall_counter_packets_total Packets matched by Janus nftables named counters.\n")
                  output.write("# TYPE janus_firewall_counter_packets_total counter\n")
                  output.write("# HELP janus_firewall_counter_bytes_total Bytes matched by Janus nftables named counters.\n")
                  output.write("# TYPE janus_firewall_counter_bytes_total counter\n")
                  for counter in metadata:
                      key = (counter["family"], counter["table"], counter["name"])
                      values = observed.get(key, {})
                      labels = {
                          "family": counter["family"],
                          "table": counter["table"],
                          "chain": counter["chain"],
                          "counter": counter["name"],
                          "action": counter["action"],
                          "zone": counter["zone"],
                      }
                      output.write(metric_line("janus_firewall_counter_packets_total", labels, values.get("packets", 0)))
                      output.write(metric_line("janus_firewall_counter_bytes_total", labels, values.get("bytes", 0)))
              os.replace(tmp_path, OUT_PATH)
              tmp_path = None
          finally:
              if tmp_path is not None:
                  try:
                      os.unlink(tmp_path)
                  except FileNotFoundError:
                      pass


      if __name__ == "__main__":
          main()
    '';
  };

  mkForwardRules =
    zone:
    if zone.allowAny or false then
      [ "counter name ${zone.counter} accept" ]
    else
      map (
        allow: ''oifname "${interfaceForTarget allow.target}" counter name ${allow.counter} accept''
      ) zone.allow;

  indentLines = prefix: lines: lib.concatMapStringsSep "\n" (line: "${prefix}${line}") lines;

  mkZoneChain =
    name: zone:
    let
      rules = mkForwardRules zone;
    in
    lib.concatStringsSep "\n" (
      [
        "  # ${zone.description}"
        "  chain from-${name} {"
      ]
      ++ map (rule: "    ${rule}") rules
      ++ [ "  }" ]
    );

  zoneJumps = indentLines "    " (
    lib.mapAttrsToList (name: zone: ''iifname "${zone.interface}" jump from-${name}'') forwardZones
  );
  zoneChains = lib.concatStringsSep "\n" (lib.mapAttrsToList mkZoneChain forwardZones);
in
{
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
        table inet filter {
    ${counterObjects}

          chain input {
            type filter hook input priority 0; policy drop;

            ct state established,related counter name input_accept_established_related accept
            ct state invalid counter name input_drop_invalid drop
            iif lo counter name input_accept_loopback accept
            ip protocol icmp counter name input_accept_icmp accept

            # DHCP + DNS for local subnets.
            iifname { ${topology.interfaceSet topology.serviceInterfaces} } udp dport { 53, 67 } counter name input_accept_dhcp_dns accept
            iifname { ${topology.interfaceSet topology.serviceInterfaces} } tcp dport 53 counter name input_accept_dhcp_dns accept

            # Tailscale direct path from WAN. Tunnel traffic is authenticated by
            # WireGuard; Tailscale ACLs remain the peer policy boundary.
            iifname "${topology.wan}" udp dport 41641 counter name input_accept_tailscale_direct_udp accept

            # Tailnet is the admin plane for Janus itself.
            iifname "tailscale0" counter name input_accept_tailnet_admin accept

            # SSH from trusted + management only.
            iifname { "${topology.vlanInterface topology.vlans.trusted}", "br-mgmt" } tcp dport 22 counter name input_accept_ssh_admin accept

            limit rate 6/minute burst 12 packets log prefix "janus-fw input-drop " level warn
            counter name input_drop_default drop
          }

          chain forward {
            type filter hook forward priority 0; policy drop;

            ct state established,related counter name forward_accept_established_related accept
            ct state invalid counter name forward_drop_invalid drop

            # Tailscale subnet routes. Route approval and Tailscale ACLs decide
            # which peers can use these local networks.
            iifname "tailscale0" oifname { ${topology.interfaceSet topology.localForwardInterfaces} } counter name forward_accept_tailscale_to_local accept

    ${zoneJumps}

            limit rate 6/minute burst 12 packets log prefix "janus-fw forward-drop " level warn
            counter name forward_drop_default drop
          }

    ${zoneChains}

          chain output {
            type filter hook output priority 0; policy accept;
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100;
            oifname "${topology.wan}" masquerade
          }
        }
  '';

  systemd.services.janus-firewall-counters = {
    description = "Export Janus nftables named counters for Alloy textfile scraping";
    after = [ "nftables.service" ];
    wants = [ "nftables.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${firewallExporter}/bin/janus-firewall-counters";
    };
  };

  systemd.timers.janus-firewall-counters = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "15s";
      AccuracySec = "5s";
      Persistent = true;
    };
  };
}
