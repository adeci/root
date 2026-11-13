{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (self.inventory.lan) vlans hosts;
  inherit (self.inventory.router.interfaces) wan;

  # An nft set of interface names.
  interfaceSet = names: "{ ${lib.concatMapStringsSep ", " (name: ''"${name}"'') names} }";
  gatewayInterfaces = interfaceSet (map (vlan: vlan.interface) (lib.attrValues vlans));
  tailnetInterfaces = interfaceSet (
    map (vlan: vlan.interface) (lib.filter (vlan: vlan.tailnet) (lib.attrValues vlans))
  );

  # What each VLAN's clients may reach through Janus, besides replies.
  zones = {
    # Everything, vault and tenant included.
    trusted = [ "counter name forward_accept_trusted accept" ];
    iot = [ ''oifname "${wan}" counter name forward_accept_iot_to_wan accept'' ];
    # Printing to the trusted printer: LPD, IPP and JetDirect.
    guest = [
      ''oifname "${wan}" counter name forward_accept_guest_to_wan accept''
      ''oifname "${vlans.trusted.interface}" ip daddr ${hosts.printer.ip} tcp dport { 515, 631, 9100 } counter name forward_accept_guest_to_printer accept''
    ];
    # Hosts holding credentials, on their own VLAN because hosts sharing one reach each other past Janus.
    vault = [ ''oifname "${wan}" counter name forward_accept_vault_to_wan accept'' ];
    # Untrusted hosted workloads; whatever hosts them keeps them apart from each other.
    tenant = [ ''oifname "${wan}" counter name forward_accept_tenant_to_wan accept'' ];
    # Switches and access points only talk to Janus.
    mgmt = [ ];
  };

  vlansWithoutZone = lib.subtractLists (lib.attrNames zones) (lib.attrNames vlans);

  indent = lib.concatMapStrings (line: "  ${line}\n");
  zoneJumps = indent (
    lib.mapAttrsToList (name: _: ''iifname "${vlans.${name}.interface}" jump from-${name}'') zones
  );
  zoneChains = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: rules: "chain from-${name} {\n${indent rules}}\n") zones
  );

  adminInterfaces = interfaceSet [
    vlans.trusted.interface
    vlans.mgmt.interface
  ];

  chains = ''
    chain input {
      type filter hook input priority 0; policy drop;

      ct state established,related counter name input_accept_established_related accept
      ct state invalid counter name input_drop_invalid drop
      iif lo counter name input_accept_loopback accept
      ip protocol icmp counter name input_accept_icmp accept

      iifname ${gatewayInterfaces} udp dport { 53, 67 } counter name input_accept_dhcp_dns accept
      iifname ${gatewayInterfaces} tcp dport 53 counter name input_accept_dhcp_dns accept

      # Tunnel traffic is authenticated by WireGuard; Tailscale ACLs remain the peer policy boundary.
      iifname "${wan}" udp dport 41641 counter name input_accept_tailscale_direct_udp accept

      # Tailnet is the admin plane for Janus itself.
      iifname "tailscale0" counter name input_accept_tailnet_admin accept

      iifname ${adminInterfaces} tcp dport 22 counter name input_accept_ssh_admin accept

      limit rate 6/minute burst 12 packets log prefix "janus-fw input-drop " level warn
      counter name input_drop_default drop
    }

    chain forward {
      type filter hook forward priority 0; policy drop;

      ct state established,related counter name forward_accept_established_related accept
      ct state invalid counter name forward_drop_invalid drop

      # Tailscale subnet routes; the tailnet policy decides who may use them.
      iifname "tailscale0" oifname ${tailnetInterfaces} counter name forward_accept_tailscale_to_local accept

    ${zoneJumps}
      limit rate 6/minute burst 12 packets log prefix "janus-fw forward-drop " level warn
      counter name forward_drop_default drop
    }

    ${zoneChains}
    chain output {
      type filter hook output priority 0; policy accept;
    }
  '';

  # Each is <chain>_<verdict>_<what>; the metric's labels come from the name.
  counterNames = [
    "input_accept_established_related"
    "input_drop_invalid"
    "input_accept_loopback"
    "input_accept_icmp"
    "input_accept_dhcp_dns"
    "input_accept_tailscale_direct_udp"
    "input_accept_tailnet_admin"
    "input_accept_ssh_admin"
    "input_drop_default"
    "forward_accept_established_related"
    "forward_drop_invalid"
    "forward_accept_tailscale_to_local"
    "forward_drop_default"
    "forward_accept_guest_to_wan"
    "forward_accept_guest_to_printer"
    "forward_accept_iot_to_wan"
    "forward_accept_tenant_to_wan"
    "forward_accept_trusted"
    "forward_accept_vault_to_wan"
  ];
  counters = map (
    name:
    let
      parts = lib.splitString "_" name;
    in
    {
      family = "inet";
      table = "filter";
      inherit name;
      chain = builtins.elemAt parts 0;
      action = builtins.elemAt parts 1;
    }
  ) counterNames;
  counterDeclarations = lib.concatMapStrings (counter: ''
    counter ${counter.name} {
      packets 0 bytes 0
    }
  '') counters;
  counterLabels = pkgs.writeText "janus-firewall-counters.json" (builtins.toJSON counters);
in
{
  assertions = [
    {
      assertion = vlansWithoutZone == [ ];
      message = "janus firewall has no forward zone for: ${lib.concatStringsSep ", " vlansWithoutZone}";
    }
  ];

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
    table inet filter {
    ${counterDeclarations}
    ${chains}
    }

    table ip nat {
      chain postrouting {
        type nat hook postrouting priority 100;
        oifname "${wan}" masquerade
      }
    }
  '';

  systemd.services.janus-firewall-counters = {
    description = "Export Janus nftables named counters for Alloy textfile scraping";
    after = [ "nftables.service" ];
    wants = [ "nftables.service" ];
    path = [ pkgs.nftables ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.python3} ${./firewall-counters.py} ${counterLabels} ${config.monitoring.textfileDirectory}/janus-firewall-counters.prom";
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
