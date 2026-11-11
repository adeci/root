let
  inherit (import ./tailscale) addresses;

  hosts = {
    axon = {
      mac = "04:f4:1c:84:68:a6"; # sfp-sfpplus1 MAC (standalone management port)
      ip = "10.99.0.3";
      vlan = "mgmt";
    };

    nexus = {
      mac = "08:55:31:21:A7:0D";
      ip = "10.99.0.2";
      vlan = "mgmt";
    };

    nimbus = {
      mac = "04:F4:1C:EA:18:83";
      ip = "10.99.0.6";
      vlan = "mgmt";
    };

    zephyr = {
      mac = "04:F4:1C:E9:EF:E5";
      ip = "10.99.0.5";
      vlan = "mgmt";
    };

    aero = {
      mac = "d4:93:90:10:8c:d1";
      ip = "10.10.0.40";
      vlan = "trusted";
    };

    atropos = {
      mac = "6c:4b:90:75:df:79";
      clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:c4:8c:38:f1:54:f6:d7:a4"; # systemd-networkd
      ip = "10.10.0.60";
      vlan = "trusted";
    };

    clotho = {
      mac = "6c:4b:90:1a:87:8f";
      clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:66:3c:b9:3c:ea:ef:3e:fa"; # systemd-networkd
      ip = "10.10.0.61";
      vlan = "trusted";
    };

    lachesis = {
      mac = "6c:4b:90:18:da:ca";
      clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:73:db:fa:94:7e:19:65:ef"; # systemd-networkd
      ip = "10.40.0.62";
      vlan = "vault";
    };

    leviathan = {
      mac = "e4:3d:1a:cd:96:60";
      ip = "10.10.0.20";
      vlan = "trusted";
    };

    leviathan-idrac = {
      mac = "b0:7b:25:f0:b0:c8";
      ip = "10.10.0.21";
      vlan = "trusted";
    };

    printer = {
      mac = "9c:93:4e:2e:6e:e1";
      ip = "10.10.0.50";
      vlan = "trusted";
      publishDns = false;
    };

    sequoia = {
      mac = "00:e0:4c:6d:c5:c9";
      ip = "10.10.0.10";
      vlan = "trusted";
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
    "atlas.decio.us" = addresses.sequoia;
    "mandate.decio.us" = addresses.lachesis;
  };
}
