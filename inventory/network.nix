# The machines and the home network.
{
  lan = {
    domain = "lan";

    vlans = {
      trusted = {
        id = 10;
        # The only subnet route: vault and tenant hosts join the tailnet themselves.
        tailnet = true;
      };
      iot.id = 20;
      guest.id = 30;
      vault.id = 40;
      tenant.id = 50;
      mgmt = {
        id = 99;
        interface = "br-mgmt";
      };
    };

    dns = {
      "paperless.decio.us".lan = "sequoia";
      "atlas.decio.us".tailnet = "sequoia";
      "mandate.decio.us".tailnet = "lachesis";
    };
  };

  tailnet = {
    domain = "cymric-daggertooth.ts.net";
    deviceTags = {
      delphi = [ "tag:work" ];
      malum = [ "tag:work" ];
    };
  };

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
    roles = {
      wan = "eth4";
      lan = "sfpPlus2";
      mgmt = "eth5";
    };
  };

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
        clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:c4:8c:38:f1:54:f6:d7:a4";
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
        clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:66:3c:b9:3c:ea:ef:3e:fa";
        ip = "10.10.0.61";
        vlan = "trusted";
      };
    };

    conduit = {
      tags = [ "adeci-net" ];
      tailnet = "100.115.94.1";
    };

    daedalus = {
      class = "darwin";
      tags = [ "adeci-net" ];
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
        clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:73:db:fa:94:7e:19:65:ef";
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

  devices = {
    aero.lan = {
      mac = "d4:93:90:10:8c:d1";
      ip = "10.10.0.40";
      vlan = "trusted";
    };

    kat-laptop.lan = {
      mac = "74:d4:dd:05:4c:2a";
      ip = "10.10.0.41";
      vlan = "trusted";
    };

    printer.lan = {
      mac = "9c:93:4e:2e:6e:e1";
      ip = "10.10.0.50";
      vlan = "trusted";
      publishDns = false;
    };
  };

  appliances = {
    nexus = {
      model = "CRS328-24P-4S+RM";
      location = "main rack";
      lan = {
        mac = "08:55:31:21:A7:0D";
        ip = "10.99.0.2";
        vlan = "mgmt";
      };
      managementPort = "ether1";
      fallbackAddress = "172.16.0.2/24";
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
        ether1.cable = "janus:eth5";
        ether2 = {
          vlan = "mgmt";
          tagged = [
            "trusted"
            "iot"
            "guest"
          ];
          poe = "auto-on";
          cable = "zephyr:ether1";
        };
        ether3 = {
          vlan = "mgmt";
          tagged = [
            "trusted"
            "iot"
            "guest"
          ];
          poe = "auto-on";
          cable = "nimbus:ether1";
        };
        ether4.cable = "kat-laptop";
        ether6.cable = "sequoia";
        ether9.cable = "printer";
        ether10.cable = "leviathan-idrac";
        ether18.cable = "bramble";
        sfp-sfpplus1 = {
          trunk = true;
          cable = "janus:sfpPlus2";
        };
        sfp-sfpplus2 = {
          vlan = "mgmt";
          tagged = [
            "trusted"
            "iot"
            "guest"
            "vault"
          ];
          cable = "axon:sfp-sfpplus1";
        };
        sfp-sfpplus3.cable = "leviathan:eno12399np0";
        sfp-sfpplus4 = {
          vlan = "tenant";
          cable = "leviathan:eno12409np1";
        };
      };
    };

    axon = {
      model = "CRS310-8G+2S+IN";
      location = "upstairs mini rack";
      lan = {
        mac = "04:f4:1c:84:68:a6"; # sfp-sfpplus1's MAC
        ip = "10.99.0.3";
        vlan = "mgmt";
      };
      managementPort = "sfp-sfpplus1";
      fallbackPort = "ether1";
      fallbackAddress = "172.16.0.3/24";
      vlans = [
        "trusted"
        "iot"
        "guest"
        "vault"
        "mgmt"
      ];
      defaultVlan = "trusted";
      ports = {
        ether1 = {
          vlan = "vault";
          cable = "lachesis";
        };
        ether2.cable = "aero";
        ether3.cable = "clotho";
        ether4 = {
          vlan = "guest";
          label = "malum dock";
        };
        ether5.cable = "atropos";
        ether7.cable = "praxis";
        sfp-sfpplus1.trunk = true;
      };
    };

    zephyr = {
      model = "cAP-ax";
      location = "living room";
      lan = {
        mac = "04:F4:1C:E9:EF:E5";
        ip = "10.99.0.5";
        vlan = "mgmt";
      };
      managementPort = "ether1";
      fallbackAddress = "172.16.0.5/24";
      wifi = [
        "main"
        "guest"
        "iot"
      ];
    };

    nimbus = {
      model = "cAP-ax";
      location = "upstairs";
      lan = {
        mac = "04:F4:1C:EA:18:83";
        ip = "10.99.0.6";
        vlan = "mgmt";
      };
      managementPort = "ether1";
      fallbackAddress = "172.16.0.6/24";
      wifi = [
        "main"
        "guest"
        "iot"
      ];
    };
  };

  wifi = {
    main = {
      ssid = "Aether";
      vlan = "trusted";
      primary = true;
    };

    guest = {
      ssid = "Penumbra";
      vlan = "guest";
    };

    iot = {
      ssid = "Mycelium";
      vlan = "iot";
      hidden = true;
    };
  };
}
