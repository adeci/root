# The shape of network.nix and its derived values.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ./lib.nix { inherit lib; })
    carriedVlans
    inBlock
    ipv4Address
    macAddress
    parseCableEnd
    ;

  # The whole inventory. Inside an entry's own submodule, `config` is that entry.
  inventory = config;

  models = import ./routeros-models.nix;

  tailnetAddress = lib.mkOptionType {
    name = "tailnetAddress";
    description = "IPv4 address in ${inventory.tailnet.cidr}";
    check = address: ipv4Address.check address && inBlock inventory.tailnet.cidr address;
    merge = lib.options.mergeEqualOption;
  };

  # Each of these accepts only the names the inventory defines.
  vlanName = types.enum (lib.attrNames inventory.lan.vlans);
  hostName = types.enum (lib.attrNames inventory.lan.hosts);
  routerPortLabel = types.enum (lib.attrNames inventory.router.ports);
  machineName = types.enum (lib.attrNames inventory.machines);
  wifiName = types.enum (lib.attrNames inventory.wifi);

  # Machines and every LAN host; a machine without a reservation can still be cabled.
  cableEndNames = lib.sort lib.lessThan (
    lib.unique (lib.attrNames inventory.machines ++ lib.attrNames inventory.lan.hosts)
  );

  cableEnd = lib.mkOptionType {
    name = "cableEnd";
    description = "cable end <name> or <name>:<port>, <name> being one of ${lib.concatStringsSep ", " cableEndNames}";
    check =
      end:
      let
        parsed = parseCableEnd end;
      in
      builtins.isString end && parsed != null && lib.elem parsed.name cableEndNames;
    merge = lib.options.mergeEqualOption;
  };

  # A DHCP reservation: the address a MAC gets on a VLAN.
  reservation = {
    options = {
      mac = mkOption { type = macAddress; };
      ip = mkOption { type = ipv4Address; };
      vlan = mkOption { type = vlanName; };
    };
  };
in
{
  options = {
    # lan

    lan = {
      domain = mkOption {
        type = types.str;
        description = "The LAN's DNS domain; each host answers as <name>.<domain>.";
      };

      vlans = mkOption {
        type = types.attrsOf (
          types.submodule (
            { config, ... }:
            {
              options = {
                id = mkOption {
                  type = types.ints.between 1 4094;
                  description = "The VLAN's 802.1Q tag. It also numbers the VLAN's addresses: VLAN 20 is 10.20.0.0/24.";
                };
                prefix = mkOption {
                  type = types.str;
                  readOnly = true;
                  default = "10.${toString config.id}.0";
                  description = "The first three octets of the VLAN's addresses.";
                };
                cidr = mkOption {
                  type = types.str;
                  readOnly = true;
                  default = "${config.prefix}.0/24";
                  description = "The VLAN's subnet.";
                };
                gateway = mkOption {
                  type = ipv4Address;
                  readOnly = true;
                  default = "${config.prefix}.1";
                  description = "The router's address on the VLAN.";
                };
                dhcpPool = {
                  start = mkOption {
                    type = ipv4Address;
                    readOnly = true;
                    default = "${config.prefix}.100";
                    description = "The first address the router's DHCP server hands out. Reserved addresses stay outside the pool.";
                  };
                  end = mkOption {
                    type = ipv4Address;
                    readOnly = true;
                    default = "${config.prefix}.250";
                    description = "The last address the router's DHCP server hands out.";
                  };
                };
                tailnet = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether the router advertises the VLAN to the tailnet as a subnet route.";
                };
                interface = mkOption {
                  type = types.str;
                  default = "vlan${toString config.id}";
                  description = "The router's interface holding the VLAN's gateway: its 802.1Q device vlan<id>, or a bridge that device joins.";
                };
              };
            }
          )
        );
      };

      dns = mkOption {
        type = types.attrsOf (
          types.attrTag {
            lan = mkOption {
              type = hostName;
              description = "A LAN host, whose reserved address the name resolves to.";
            };
            tailnet = mkOption {
              type = machineName;
              description = "A machine, whose tailnet address the name resolves to.";
            };
          }
        );
        default = { };
        description = "Full DNS names the router serves to the LAN and, through Tailscale split DNS, to the tailnet. Each points at either a LAN host (lan) or a machine's tailnet address (tailnet).";
      };

      hosts = mkOption {
        type = types.attrsOf types.attrs;
        readOnly = true;
        default =
          let
            # The same record for every kind of host, so readers needn't know where it was written.
            host = lan: {
              inherit (lan) mac ip vlan;
              clientId = lan.clientId or null;
              publishDns = lan.publishDns or true;
            };
          in
          lib.mapAttrs (_: device: host device.lan) inventory.devices
          // lib.mapAttrs (_: vm: host vm.lan) inventory.vms
          // lib.mapAttrs (_: appliance: host appliance.lan) inventory.appliances
          // lib.concatMapAttrs (
            name: machine:
            lib.optionalAttrs (machine.lan != null) (
              {
                ${name} = host machine.lan;
              }
              // lib.mapAttrs' (
                label: nic: lib.nameValuePair "${name}-${label}" (host (nic // { inherit (machine.lan) vlan; }))
              ) machine.lan.extra
            )
          ) inventory.machines;
        description = "Every reserved LAN address by host name, each as { mac, clientId, ip, vlan, publishDns }: the machines (and their extra NICs), vms, devices and appliances below.";
      };

      cables = mkOption {
        type = types.listOf types.attrs;
        readOnly = true;
        default = lib.concatLists (
          lib.mapAttrsToList (
            name: appliance:
            lib.mapAttrsToList (
              port: settings:
              let
                leadsTo = parseCableEnd settings.cable;
              in
              {
                appliance = name;
                inherit port;
                to = leadsTo.name;
                toPort = leadsTo.port;
              }
            ) (lib.filterAttrs (_: settings: settings.cable != null) appliance.ports)
          ) inventory.appliances
        );
        description = "Every cable recorded on an appliance port below, once, as { appliance, port, to, toPort }: the port it is written on and the host, appliance or router it leads to. toPort is null when the cable names no port or NIC there.";
      };
    };

    # tailnet

    tailnet = {
      domain = mkOption {
        type = types.str;
        description = "The tailnet's MagicDNS domain; each machine answers as <name>.<domain>.";
      };

      cidr = mkOption {
        type = types.str;
        readOnly = true;
        default = "100.64.0.0/10";
        description = "Tailscale's CGNAT range, which every tailnet address falls inside.";
      };

      deviceTags = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "ACL tags set on tailnet devices through the Tailscale API, by hostname.";
      };

      addresses = mkOption {
        type = types.attrsOf tailnetAddress;
        readOnly = true;
        default = lib.mapAttrs (_: machine: machine.tailnet) (
          lib.filterAttrs (_: machine: machine.tailnet != null) inventory.machines
        );
        description = "The tailnet address of each machine below that has one.";
      };
    };

    # router

    router = {
      machine = mkOption {
        type = machineName;
        description = "The machine that routes the LAN.";
      };

      ports = mkOption {
        type = types.attrsOf types.str;
        description = "Its Linux interface names by the label on its case.";
      };

      roles = {
        wan = mkOption {
          type = routerPortLabel;
          description = "The port cabled to the ISP's modem.";
        };
        lan = mkOption {
          type = routerPortLabel;
          description = "The port carrying every VLAN, tagged.";
        };
        mgmt = mkOption {
          type = routerPortLabel;
          description = "The port carrying the mgmt VLAN, untagged.";
        };
      };

      interfaces = mkOption {
        type = types.attrsOf types.str;
        readOnly = true;
        default = lib.mapAttrs (_: label: inventory.router.ports.${label}) inventory.router.roles;
        description = "Its Linux interface name for each role.";
      };
    };

    # machines

    machines = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            class = mkOption {
              type = types.enum [
                "nixos"
                "darwin"
              ];
              default = "nixos";
            };
            tags = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Its clan inventory tags; portable marks a laptop that comes and goes.";
            };
            tailnet = mkOption {
              type = types.nullOr tailnetAddress;
              default = null;
              description = "Its tailnet address. Tailscale assigns it, so a reinstall can change it.";
            };
            lan = mkOption {
              type = types.nullOr (
                types.submodule {
                  imports = [ reservation ];
                  options = {
                    clientId = mkOption {
                      type = types.nullOr (types.strMatching "[0-9a-fA-F]{2}(:[0-9a-fA-F]{2})*");
                      default = null;
                      description = "The DHCP client id systemd-networkd sends; the reservation matches it instead of the MAC.";
                    };
                    extra = mkOption {
                      type = types.attrsOf (
                        types.submodule {
                          options = {
                            mac = mkOption { type = macAddress; };
                            ip = mkOption { type = ipv4Address; };
                          };
                        }
                      );
                      default = { };
                      description = "More NICs on the machine's VLAN, such as a BMC; each becomes a host named <machine>-<label>.";
                    };
                  };
                }
              );
              default = null;
              description = "Its reserved address on the home LAN; null for a machine that isn't on it.";
            };
          };
        }
      );
      default = { };
      description = "The clan machines; the clan inventory is built from these.";
    };

    # vms

    vms = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            host = mkOption {
              type = machineName;
              description = "The machine it runs on.";
            };
            lan = mkOption { type = types.submodule reservation; };
          };
        }
      );
      default = { };
    };

    # devices

    devices = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.lan = mkOption {
            type = types.submodule {
              imports = [ reservation ];
              options.publishDns = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the router answers DNS for <name>.<lan domain>.";
              };
            };
          };
        }
      );
      default = { };
      description = "LAN devices this repo doesn't manage, such as a printer or a guest's laptop.";
    };

    # appliances

    appliances =
      let
        # One port of an appliance, given the appliance's name and settings.
        port =
          applianceName: appliance:
          types.submodule (
            { name, config, ... }:
            let
              leadsTo = parseCableEnd config.cable;
              # A cable written on another appliance's port that leads to this one.
              incoming = lib.findFirst (
                cable: cable.to == applianceName && cable.toPort == name
              ) null inventory.lan.cables;
              bridged = vlan: lib.elem vlan appliance.vlans;
            in
            {
              options = {
                vlan = mkOption {
                  type = types.nullOr vlanName;
                  default = appliance.defaultVlan;
                  description = "The VLAN the port carries untagged.";
                };
                tagged = mkOption {
                  type = types.listOf vlanName;
                  default = [ ];
                  description = "The VLANs the port also carries, tagged.";
                };
                trunk = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether the port carries every VLAN of the switch, tagged; on the management port the appliance's own VLAN stays untagged.";
                };
                carries = mkOption {
                  type = types.attrs;
                  readOnly = true;
                  default =
                    if name == appliance.managementPort then
                      carriedVlans appliance.lan.vlan (
                        if appliance.wifi != null then
                          map (network: inventory.wifi.${network}.vlan) appliance.wifi
                        else
                          lib.optionals config.trunk (lib.remove appliance.lan.vlan appliance.vlans)
                      )
                    else if config.trunk then
                      carriedVlans null appliance.vlans
                    else
                      carriedVlans (if bridged config.vlan then config.vlan else null) (lib.filter bridged config.tagged);
                  description = "What the port carries, as { untagged, tagged }. The management port carries the appliance's own VLAN untagged and tags its Wi-Fi VLANs or, as a trunk, the switch's other VLANs. Any other port carries only VLANs the switch bridges.";
                };
                poe = mkOption {
                  type = types.nullOr (
                    types.enum [
                      "auto-on"
                      "forced-on"
                      "off"
                    ]
                  );
                  default = null;
                  description = "The port's PoE output; RouterOS's default when null.";
                };
                cable = mkOption {
                  type = types.nullOr cableEnd;
                  default = null;
                  description = ''Where the cable in this port leads: a host ("sequoia"), one NIC of a host ("leviathan:eno12399np0"), a port of another appliance ("axon:sfp-sfpplus1") or a router port by its chassis label ("janus:eth5"). Each cable is written once; the other end of a cable to an appliance or the router is derived.'';
                };
                label = mkOption {
                  type = types.nullOr types.str;
                  default =
                    if config.cable == null then
                      if incoming == null then null else "${incoming.appliance} ${incoming.port}"
                    else if leadsTo.port == null then
                      leadsTo.name
                    else
                      "${leadsTo.name} ${leadsTo.port}";
                  description = "The port's comment on the appliance: where its cable leads. Set it only on a port without a recorded cable.";
                };
              };
            }
          );
      in
      mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, config, ... }:
            {
              options = {
                model = mkOption {
                  type = types.enum (lib.attrNames models);
                  description = "The MikroTik model, one of flake/inventory/routeros-models.nix.";
                };
                location = mkOption {
                  type = types.str;
                  description = "Where it is installed.";
                };
                lan = mkOption {
                  type = types.submodule reservation;
                  description = "Its management address.";
                };
                api = {
                  address = mkOption {
                    type = ipv4Address;
                    readOnly = true;
                    default = config.lan.ip;
                    description = "The address its RouterOS API answers on.";
                  };
                  port = mkOption {
                    type = types.port;
                    readOnly = true;
                    default = 8728;
                    description = "The port its RouterOS API answers on.";
                  };
                };
                managementPort = mkOption {
                  type = types.str;
                  description = "The port it is managed through. It stays out of the bridge and keeps a DHCP client for the management address.";
                };
                fallbackPort = mkOption {
                  type = types.str;
                  default = config.managementPort;
                  description = "The port that takes fallbackAddress and also keeps a DHCP client.";
                };
                fallbackAddress = mkOption {
                  type = types.str;
                  description = "A static address with prefix length, for reaching it from a laptop when DHCP fails.";
                };
                vlans = mkOption {
                  type = types.listOf vlanName;
                  default = [ ];
                  description = "The VLANs a switch bridges; empty on an access point.";
                };
                defaultVlan = mkOption {
                  type = types.nullOr vlanName;
                  default = null;
                  description = "The VLAN a switch port carries untagged unless the port names another.";
                };
                wifi = mkOption {
                  type = types.nullOr (types.nonEmptyListOf wifiName);
                  default = null;
                  description = "The Wi-Fi networks an access point broadcasts: the first from each radio's main interface, the others as virtual interfaces. Null on a switch.";
                };
                ports = mkOption {
                  type = types.attrsOf (port name config);
                  description = "Its ports by interface name: ether1, sfp-sfpplus1 and so on.";
                };
              };

              # Every port of the model, so each one has its settings and label.
              config.ports = lib.genAttrs models.${config.model}.ports (_: { });
            }
          )
        );
        default = { };
        description = "The MikroTik switches and access points, and what each of their ports carries and is cabled to.";
      };

    # wifi

    wifi = mkOption {
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options = {
              ssid = mkOption {
                type = types.str;
                description = "The network name clients see.";
              };
              vlan = mkOption {
                type = vlanName;
                description = "The VLAN its clients join.";
              };
              security = mkOption {
                type = types.enum [
                  "wpa2"
                  "wpa3"
                  "wpa2-wpa3"
                ];
                default = "wpa2-wpa3";
                description = "The WPA versions clients may use.";
              };
              hidden = mkOption {
                type = types.bool;
                default = false;
                description = "Whether the access points hide the SSID.";
              };
              secret = mkOption {
                type = types.str;
                readOnly = true;
                default = "wifi-${lib.toLower config.ssid}";
                description = "The clan secret holding its passphrase.";
              };
            };
          }
        )
      );
      default = { };
      description = "The Wi-Fi networks; each access point lists the ones it broadcasts.";
    };

    # routeros, which the appliances run (not in network.nix)

    routeros = {
      models = mkOption {
        type = types.attrsOf types.attrs;
        readOnly = true;
        default = models;
        description = "MikroTik hardware by model, from routeros-models.nix, each with its full list of ports.";
      };

      admin = mkOption {
        type = types.attrs;
        readOnly = true;
        default = {
          user = "admin";
          secret = "routeros-password";
        };
        description = "The account netinstall creates and Terraform manages the appliances with; its password is a clan secret.";
      };

      exporter = mkOption {
        type = types.attrs;
        readOnly = true;
        default = {
          inherit (inventory.router) machine;
          generator = "routeros-exporter";
          file = "password";
          user = "prometheus";
        };
        description = "The read-only RouterOS API account metrics scraping uses; its password lives in the router's clan vars.";
      };
    };

    # the other data files, untyped; references.nix checks the names they use

    b2 = mkOption {
      type = types.raw;
      description = "inventory/b2.nix: the Backblaze B2 buckets.";
    };

    cloudflare = mkOption {
      type = types.raw;
      description = "inventory/cloudflare.nix: the zones, tunnels, DNS records, redirects and firewall rules.";
    };

    ingress = mkOption {
      type = types.raw;
      description = "inventory/ingress.nix: the public edges and the streams they forward.";
    };

    clanInstances = mkOption {
      type = types.raw;
      description = "inventory/clan-instances.nix: the clan service instances.";
    };

    tailscalePolicy = mkOption {
      type = types.raw;
      description = "inventory/tailscale-policy.nix: the tailnet's access policy.";
    };

    # the rules, from rules.nix and references.nix

    assertions = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "The rules from rules.nix and references.nix, each { assertion, message }.";
    };
  };
}
