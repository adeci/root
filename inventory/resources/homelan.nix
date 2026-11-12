let
  machines = import ../machines.nix;
  routerosDevices = import ./routeros/devices.nix;

  # Devices that are neither clan machines nor managed switches/APs; those bring their own reservation.
  devices = {
    aero = {
      mac = "d4:93:90:10:8c:d1";
      ip = "10.10.0.40";
      vlan = "trusted";
    };

    printer = {
      mac = "9c:93:4e:2e:6e:e1";
      ip = "10.10.0.50";
      vlan = "trusted";
      publishDns = false;
    };

    # microVMs on leviathan
    scylla = {
      mac = "02:00:00:32:00:0a";
      ip = "10.50.0.10";
      vlan = "tenant";
    };

    charybdis = {
      mac = "02:00:00:32:00:0b";
      ip = "10.50.0.11";
      vlan = "tenant";
    };
  };

  withLan = builtins.filter (name: machines.${name} ? lan) (builtins.attrNames machines);

  # A machine's reservation, plus one per extra interface (e.g. a BMC) named <machine>-<label>.
  machineHosts = builtins.listToAttrs (
    builtins.concatMap (
      name:
      let
        inherit (machines.${name}) lan;
      in
      [
        {
          inherit name;
          value = builtins.removeAttrs lan [ "extra" ];
        }
      ]
      ++ map (label: {
        name = "${name}-${label}";
        value = {
          inherit (lan) vlan;
        }
        // lan.extra.${label};
      }) (builtins.attrNames (lan.extra or { }))
    ) withLan
  );

  hosts = devices // machineHosts // builtins.mapAttrs (_: device: device.lan) routerosDevices;
in
{
  domain = "lan";

  vlans = {
    trusted = {
      id = 10;
      prefix = "10.10.0";
      cidr = "10.10.0.0/24";
      gateway = "10.10.0.1";
      tailnet = true;
      dhcpPool = {
        start = "10.10.0.100";
        end = "10.10.0.250";
      };
    };

    iot = {
      id = 20;
      prefix = "10.20.0";
      cidr = "10.20.0.0/24";
      gateway = "10.20.0.1";
      dhcpPool = {
        start = "10.20.0.100";
        end = "10.20.0.250";
      };
    };

    guest = {
      id = 30;
      prefix = "10.30.0";
      cidr = "10.30.0.0/24";
      gateway = "10.30.0.1";
      dhcpPool = {
        start = "10.30.0.100";
        end = "10.30.0.250";
      };
    };

    vault = {
      id = 40;
      prefix = "10.40.0";
      cidr = "10.40.0.0/24";
      gateway = "10.40.0.1";
      dhcpPool = {
        start = "10.40.0.100";
        end = "10.40.0.250";
      };
    };

    tenant = {
      id = 50;
      prefix = "10.50.0";
      cidr = "10.50.0.0/24";
      gateway = "10.50.0.1";
      dhcpPool = {
        start = "10.50.0.100";
        end = "10.50.0.250";
      };
    };

    mgmt = {
      id = 99;
      prefix = "10.99.0";
      cidr = "10.99.0.0/24";
      gateway = "10.99.0.1";
      dhcpPool = {
        start = "10.99.0.100";
        end = "10.99.0.250";
      };
      interface = "br-mgmt";
    };
  };

  inherit hosts;

  # Served by janus to the LAN and, through Tailscale split DNS, to the tailnet; atlas and mandate only listen on the tailnet.
  dns.records = {
    "paperless.decio.us" = hosts.sequoia.ip;
    "atlas.decio.us" = machines.sequoia.tailnet;
    "mandate.decio.us" = machines.lachesis.tailnet;
  };

  # The machine routing the LAN, its chassis labels mapped to Linux names, and the label per role.
  router = {
    machine = "janus";
    # Qotom Q20321G9, plug-tested 2026-04-12: ethN by RJ45 label (2.5G igc), sfpPlus1/2 right top/bottom (10G ixgbe).
    ports = {
      eth1 = "enp6s0";
      eth2 = "enp7s0";
      eth3 = "enp4s0";
      eth4 = "enp5s0";
      eth5 = "enp8s0";
      sfpPlus1 = "eno2";
      sfpPlus2 = "eno1";
      sfpPlus3 = "eno3";
      sfpPlus4 = "eno4";
    };
    # wan leads to the ISP, lan carries every VLAN tagged, mgmt carries mgmt untagged.
    roles = {
      wan = "eth4";
      lan = "sfpPlus2";
      mgmt = "eth5";
    };
  };

  # Known cables, one per entry; ends are "<device>:<port>" (the router by chassis label), a host with a single cable may omit its port, and "isp" is the ISP's modem.
  links = [
    {
      a = "janus:eth4";
      b = "isp";
    }
    {
      a = "janus:sfpPlus2";
      b = "nexus:sfp-sfpplus1";
    }
    {
      a = "janus:eth5";
      b = "nexus:ether1";
    }
    {
      a = "nexus:sfp-sfpplus2";
      b = "axon:sfp-sfpplus1";
    }
    {
      a = "nexus:sfp-sfpplus3";
      b = "leviathan:eno12399np0";
    }
    {
      a = "nexus:sfp-sfpplus4";
      b = "leviathan:eno12409np1";
      vlan = "tenant"; # what the host end carries instead of the host's own VLAN
    }
    {
      a = "nexus:ether2";
      b = "zephyr:ether1";
    }
    {
      a = "nexus:ether3";
      b = "nimbus:ether1";
    }
    {
      a = "axon:ether1";
      b = "lachesis";
    }
  ];
}
