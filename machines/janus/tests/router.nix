{
  inputs,
  pkgs,
  self,
}:
let
  inherit (pkgs) lib;
  inherit (self.inventory) lan machines router;
  inherit (self.inventory.routeros) exporter;

  # Each cable into janus is a network of its own in the test.
  cables = {
    wan = 1;
    lan = 2;
    mgmt = 3;
  };

  # The ISP's end of janus's WAN cable, and a host on the internet behind it, both played by the isp machine.
  wanGateway = "198.51.100.1";
  internet = {
    name = "example.com";
    address = "203.0.113.10";
  };

  # The internet's root zone, signed with a key janus trusts in place of the real root's; every NTP pool server is the internet host.
  rootZone = pkgs.runCommand "root-zone" { nativeBuildInputs = [ pkgs.ldns.examples ]; } ''
    cat > root.zone <<EOF
    . 3600 IN SOA a.root-servers.net. hostmaster.root-servers.net. 1 1800 900 604800 86400
    . 3600 IN NS a.root-servers.net.
    a.root-servers.net. 3600 IN A ${wanGateway}
    ${internet.name}. 3600 IN A ${internet.address}
    *.pool.ntp.org. 3600 IN A ${internet.address}
    EOF
    key=$(ldns-keygen -a ECDSAP256SHA256 -k .)
    mkdir "$out"
    # Valid from before this build until long after, since the signed zone is cached.
    ldns-signzone -i 20200101 -e 20800101 -f "$out/root.zone" root.zone "$key"
    cp "$key.ds" "$out/trust-anchor"
  '';

  # What a host's DHCP client does with a lease: takes the address, the default route and the DNS server.
  udhcpcScript = pkgs.writeShellScript "udhcpc-script" ''
    [ "$1" = bound ] || exit 0
    ip address add "$ip/$mask" dev "$interface"
    ip route add default via "$router"
    echo "nameserver $dns" > "/etc/netns/$(ip netns identify)/resolv.conf"
  '';
in
pkgs.testers.runNixOSTest {
  name = "janus-router";
  node.specialArgs = { inherit self inputs; };

  nodes.janus = {
    imports = [
      ../../../flake/tests/clan-stand-in.nix
      # Declares the monitoring options the router modules read.
      (import ../../../clan-services/monitoring).perMachine.nixosModule
      ../modules/router
    ];

    virtualisation.interfaces = {
      ${router.interfaces.wan}.vlan = cables.wan;
      ${router.interfaces.lan}.vlan = cables.lan;
      ${router.interfaces.mgmt}.vlan = cables.mgmt;
    };

    # The ports janus's monitoring agent settings give its exporters.
    monitoring.exporters = (import ../monitoring self.inventory).exporters;
    # The real password is set with clan vars set, so nothing generates it; no RouterOS device answers here anyway.
    clan.core.vars.generators.${exporter.generator}.script = ''touch "$out/${exporter.file}"'';
    # As base.nix runs it on every machine; the firewall decides who reaches it.
    services.openssh.enable = true;
    services.unbound = {
      enableRootTrustAnchor = false;
      settings.server.trust-anchor-file = "${rootZone}/trust-anchor";
    };
  };

  nodes.isp = {
    virtualisation.interfaces.wan.vlan = cables.wan;
    networking = {
      useNetworkd = true;
      useDHCP = false;
      firewall.enable = false;
      # A DNS query to any server on the internet reaches the root zone here.
      nftables = {
        enable = true;
        tables.internet-dns = {
          family = "ip";
          content = ''
            chain prerouting {
              type nat hook prerouting priority dstnat;
              meta l4proto { tcp, udp } th dport 53 redirect
            }
          '';
        };
      };
    };
    systemd.network.networks."10-wan" = {
      matchConfig.Name = "wan";
      address = [
        "${wanGateway}/24"
        "${internet.address}/32"
      ];
      networkConfig.DHCPServer = true;
    };
    services.bind = {
      enable = true;
      zones."." = {
        master = true;
        file = "${rootZone}/root.zone";
      };
    };
    # The internet's time server: its own clock, as good as a stratum 1 server's.
    services.chrony = {
      enable = true;
      servers = [ ];
      extraConfig = ''
        local stratum 1
        allow
      '';
    };
    environment.systemPackages = [ pkgs.dnsutils ];
  };

  # Plays the switches and every host on them, each host in a network namespace of its own.
  nodes.clients = {
    virtualisation.interfaces = {
      trunk.vlan = cables.lan;
      mgmt.vlan = cables.mgmt;
    };
    networking.useDHCP = false;
    environment.systemPackages = [
      pkgs.dnsutils
      pkgs.chrony
    ];
  };

  testScript =
    { nodes, ... }:
    ''
      inventory_json = ${
        builtins.toJSON (
          builtins.toJSON {
            inherit lan machines router;
            tailnet = self.inventory.tailnet.addresses;
          }
        )
      }
      wan_gateway = "${wanGateway}"
      internet_name = "${internet.name}"
      internet_address = "${internet.address}"
      ssh_port = ${toString (lib.head nodes.janus.services.openssh.ports)}
      exporter_ports = ${builtins.toJSON (lib.attrValues nodes.janus.monitoring.exporters)}
      busybox = "${lib.getExe pkgs.busybox}"
      udhcpc_script = "${udhcpcScript}"
    ''
    + builtins.readFile ./router.py;
}
