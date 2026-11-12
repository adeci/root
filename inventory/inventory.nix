# The fleet and the home network as plain data.
{
  lan = {
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

    # Served by janus to the LAN and, through Tailscale split DNS, to the tailnet; atlas and mandate only listen on the tailnet.
    dns.records = {
      "paperless.decio.us".lan = "sequoia";
      "atlas.decio.us".tailnet = "sequoia";
      "mandate.decio.us".tailnet = "lachesis";
    };
  };

  tailnet = {
    # The tailnet's MagicDNS domain; each machine answers as <name>.<domain>.
    domain = "cymric-daggertooth.ts.net";
    # Tailscale's CGNAT range; every tailnet address falls inside it.
    cidr = "100.64.0.0/10";
    # ACL tags set on tailnet devices through the Tailscale API, by hostname.
    deviceTags = {
      delphi = [ "tag:work" ];
      malum = [ "tag:work" ];
    };
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

  # One entry per clan machine, the source of the clan inventory, LAN reservations and tailnet addresses (Tailscale assigns those; a reinstall can change them).
  machines = {
    aegis = {
      tags = [
        "adeci-net"
        "wifi-preload"
        "portable"
      ];
      tailnet = "100.121.2.13";
    };

    atropos = {
      tags = [ "adeci-net" ];
      tailnet = "100.94.70.105";
      lan = {
        mac = "6c:4b:90:75:df:79";
        clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:c4:8c:38:f1:54:f6:d7:a4"; # systemd-networkd
        ip = "10.10.0.60";
        vlan = "trusted";
      };
    };

    bramble = {
      tags = [ "adeci-net" ];
      tailnet = "100.74.133.117";
    };

    chrysalis = {
      tags = [
        "adeci-net-ephemeral"
        "wifi-preload"
      ];
    };

    clotho = {
      tags = [ "adeci-net" ];
      tailnet = "100.87.22.3";
      lan = {
        mac = "6c:4b:90:1a:87:8f";
        clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:66:3c:b9:3c:ea:ef:3e:fa"; # systemd-networkd
        ip = "10.10.0.61";
        vlan = "trusted";
      };
    };

    conduit = {
      tags = [ "adeci-net" ];
      tailnet = "100.115.94.1";
    };

    icarus = {
      class = "darwin";
      tags = [
        "adeci-net"
        "portable"
      ];
      tailnet = "100.86.7.91";
    };

    janus = {
      tags = [ "adeci-net" ];
      tailnet = "100.65.60.15";
    };

    kasha = {
      tags = [
        "adeci-net"
        "portable"
      ];
      tailnet = "100.70.179.117";
    };

    lachesis = {
      tags = [ "adeci-net" ];
      tailnet = "100.65.112.40";
      lan = {
        mac = "6c:4b:90:18:da:ca";
        clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:73:db:fa:94:7e:19:65:ef"; # systemd-networkd
        ip = "10.40.0.62";
        vlan = "vault";
      };
    };

    leviathan = {
      tags = [ "adeci-net" ];
      tailnet = "100.90.108.13";
      lan = {
        mac = "e4:3d:1a:cd:96:60";
        ip = "10.10.0.20";
        vlan = "trusted";
        extra.idrac = {
          mac = "b0:7b:25:f0:b0:c8";
          ip = "10.10.0.21";
        };
      };
    };

    modus = {
      tags = [
        "adeci-net"
        "wifi-preload"
        "portable"
      ];
      tailnet = "100.104.206.85";
    };

    praxis = {
      tags = [
        "adeci-net"
        "wifi-preload"
        "portable"
      ];
      tailnet = "100.88.20.8";
    };

    proteus = {
      tags = [
        "adeci-net"
        "wifi-preload"
        "portable"
      ];
      tailnet = "100.78.27.92";
    };

    sequoia = {
      tags = [ "adeci-net" ];
      tailnet = "100.116.83.84";
      lan = {
        mac = "00:e0:4c:6d:c5:c9";
        ip = "10.10.0.10";
        vlan = "trusted";
      };
    };
  };

  # LAN devices that are neither clan machines nor RouterOS devices.
  appliances = {
    aero.lan = {
      mac = "d4:93:90:10:8c:d1";
      ip = "10.10.0.40";
      vlan = "trusted";
    };

    printer.lan = {
      mac = "9c:93:4e:2e:6e:e1";
      ip = "10.10.0.50";
      vlan = "trusted";
      publishDns = false;
    };
  };

  vms = {
    scylla = {
      host = "leviathan";
      lan = {
        mac = "02:00:00:32:00:0a";
        ip = "10.50.0.10";
        vlan = "tenant";
      };
    };

    charybdis = {
      host = "leviathan";
      lan = {
        mac = "02:00:00:32:00:0b";
        ip = "10.50.0.11";
        vlan = "tenant";
      };
    };
  };

  routeros = {
    # Per MikroTik model: its RouterOS architecture, extra packages, port counts and radios.
    models = {
      "CRS328-24P-4S+RM" = {
        arch = "arm";
        etherPorts = 24;
        sfpPorts = 4;
      };
      "CRS310-8G+2S+IN" = {
        arch = "arm";
        etherPorts = 8;
        sfpPorts = 2;
      };
      "cAP-ax" = {
        arch = "arm64";
        extraPackages = [ "wifi-qcom" ];
        etherPorts = 2;
        sfpPorts = 0;
        # wifi1 is 5GHz and wifi2 2.4GHz; these ids are stable after netinstall.
        radios = [
          {
            name = "wifi1";
            id = "*2";
          }
          {
            name = "wifi2";
            id = "*3";
          }
        ];
      };
    };

    # SSIDs by name; each access point lists the ones it broadcasts.
    ssids = {
      main = {
        ssid = "Aether";
        vlan = "trusted";
        security = "wpa2-wpa3";
        secret = "wifi-aether";
        primary = true;
      };
      guest = {
        ssid = "Penumbra";
        vlan = "guest";
        security = "wpa2-wpa3";
        secret = "wifi-penumbra";
      };
      iot = {
        ssid = "Mycelium";
        vlan = "iot";
        security = "wpa2-wpa3";
        hidden = true;
        secret = "wifi-mycelium";
      };
    };

    devices = {
      # Main rack
      nexus = {
        model = "CRS328-24P-4S+RM";

        lan = {
          mac = "08:55:31:21:A7:0D";
          ip = "10.99.0.2";
          vlan = "mgmt";
        };

        managementPort = "ether1"; # standalone, not in bridge, keeps DHCP client

        vlans = [
          "trusted"
          "iot"
          "guest"
          "vault"
          "tenant"
          "mgmt"
        ];

        defaultVlan = "trusted";

        ports = {
          "sfp-sfpplus1" = {
            trunk = true;
            comment = "Uplink — janus (10G SFP+)";
          };
          "sfp-sfpplus2" = {
            hybrid = true;
            vlan = "mgmt";
            tagged = [
              "trusted"
              "iot"
              "guest"
              "vault"
            ];
            comment = "Uplink — axon (10G SFP+)";
          };
          "sfp-sfpplus3" = {
            comment = "Server — leviathan trusted (10G SFP+)";
          };
          "sfp-sfpplus4" = {
            vlan = "tenant";
            comment = "Server — leviathan microVM tenants (10G SFP+)";
          };
          "ether2" = {
            hybrid = true;
            vlan = "mgmt";
            tagged = [
              "trusted"
              "iot"
              "guest"
            ];
            poe = "auto-on";
            comment = "WAP — zephyr (PoE+)";
          };
          "ether3" = {
            hybrid = true;
            vlan = "mgmt";
            tagged = [
              "trusted"
              "iot"
              "guest"
            ];
            poe = "auto-on";
            comment = "WAP — nimbus (PoE+)";
          };
        };

        fallbackAddress = "172.16.0.2/24";
      };

      # Upstairs mini rack
      axon = {
        model = "CRS310-8G+2S+IN";

        lan = {
          mac = "04:f4:1c:84:68:a6"; # sfp-sfpplus1 MAC (standalone management port)
          ip = "10.99.0.3";
          vlan = "mgmt";
        };

        managementPort = "sfp-sfpplus1";
        fallbackPort = "ether1"; # fallback IP goes here for local laptop recovery

        vlans = [
          "trusted"
          "iot"
          "guest"
          "vault"
          "mgmt"
        ];

        defaultVlan = "trusted";

        ports = {
          "sfp-sfpplus1" = {
            trunk = true;
            comment = "Downlink — nexus (10G SFP+)";
          };
          "ether1" = {
            vlan = "vault";
            comment = "Server — lachesis";
          };
          "ether4" = {
            vlan = "guest";
            comment = "Penumbra guest device";
          };
        };

        fallbackAddress = "172.16.0.3/24";
      };

      # Living room
      zephyr = {
        model = "cAP-ax";

        lan = {
          mac = "04:F4:1C:E9:EF:E5";
          ip = "10.99.0.5";
          vlan = "mgmt";
        };

        managementPort = "ether1";

        wifi = [
          "main"
          "guest"
          "iot"
        ];

        fallbackAddress = "172.16.0.5/24";
      };

      # Upstairs
      nimbus = {
        model = "cAP-ax";

        lan = {
          mac = "04:F4:1C:EA:18:83";
          ip = "10.99.0.6";
          vlan = "mgmt";
        };

        managementPort = "ether1";

        wifi = [
          "main"
          "guest"
          "iot"
        ];

        fallbackAddress = "172.16.0.6/24";
      };
    };

    # Read-only API account for metrics scraping; its password lives in this machine's vars.
    exporter = {
      machine = "janus";
      generator = "routeros-exporter";
      file = "password";
      user = "prometheus";
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
