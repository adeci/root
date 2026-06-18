{
  lib,
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
    };
    iot = {
      interface = topology.vlanInterface topology.vlans.iot;
      description = "IoT clients; internet only";
      allow = [ "wan" ];
    };
    guest = {
      interface = topology.vlanInterface topology.vlans.guest;
      description = "guest clients; internet only";
      allow = [ "wan" ];
    };
    mgmt = {
      interface = "br-mgmt";
      description = "infrastructure management; no forwarding by default";
      allow = [ ];
    };
  };

  mkForwardRules =
    zone:
    if zone.allowAny or false then
      [ "accept" ]
    else
      map (target: ''oifname "${interfaceForTarget target}" accept'') zone.allow;

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
          chain input {
            type filter hook input priority 0; policy drop;

            ct state established,related accept
            ct state invalid drop
            iif lo accept
            ip protocol icmp accept

            # DHCP + DNS for local subnets.
            iifname { ${topology.interfaceSet topology.serviceInterfaces} } udp dport { 53, 67 } accept
            iifname { ${topology.interfaceSet topology.serviceInterfaces} } tcp dport 53 accept

            # Tailscale direct path from WAN. Tunnel traffic is authenticated by
            # WireGuard; Tailscale ACLs remain the peer policy boundary.
            iifname "${topology.wan}" udp dport 41641 accept

            # Tailnet is the admin plane for Janus itself.
            iifname "tailscale0" accept

            # SSH from trusted + management only.
            iifname { "${topology.vlanInterface topology.vlans.trusted}", "br-mgmt" } tcp dport 22 accept
          }

          chain forward {
            type filter hook forward priority 0; policy drop;

            ct state established,related accept
            ct state invalid drop

            # Tailscale subnet routes. Route approval and Tailscale ACLs decide
            # which peers can use these local networks.
            iifname "tailscale0" oifname { ${topology.interfaceSet topology.localForwardInterfaces} } accept

    ${zoneJumps}
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
}
