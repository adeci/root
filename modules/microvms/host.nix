{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  hostName = config.clan.core.settings.machine.name or config.networking.hostName;
  computeHost = self.compute.hosts.${hostName} or { };
  assignedTenantNames = self.compute.assignments.${hostName} or [ ];
  assignedTenants = lib.genAttrs assignedTenantNames (
    name:
    self.compute.tenants.${name} or (throw "Unknown tenant MicroVM assignment ${name} on ${hostName}")
  );

  tenantInterface = computeHost.tenantInterface or "eno12409np1";
  tenantBridge = computeHost.tenantBridge or "br-tenant";
  tenantBridgeMac = computeHost.tenantBridgeMac or "02:00:00:00:fe:40";
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  microvm = {
    stateDir = "/var/lib/microvms";
    vms = lib.mapAttrs (_name: tenant: {
      flake = self;
      inherit (tenant.lifecycle) autostart;
      inherit (tenant.lifecycle) restartIfChanged;
    }) assignedTenants;
  };

  # Tenant VM bridge. The physical tenant NIC has no host IP; it only carries
  # VM frames to Janus VLAN 40 through Nexus.
  systemd.network = {
    netdevs.${tenantBridge} = {
      netdevConfig = {
        Name = tenantBridge;
        Kind = "bridge";
        MACAddress = tenantBridgeMac;
      };
      extraConfig = ''
        [Bridge]
        STP=no
        ForwardDelaySec=0
      '';
    };

    networks = {
      "20-tenant-lower" = {
        matchConfig.Name = tenantInterface;
        networkConfig = {
          Bridge = tenantBridge;
          DHCP = "no";
          LinkLocalAddressing = "no";
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "no";
      };

      "21-tenant-taps" = {
        matchConfig.Name = "vm-*";
        networkConfig = {
          Bridge = tenantBridge;
          LinkLocalAddressing = "no";
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "no";
      };

      "30-${tenantBridge}" = {
        matchConfig.Name = tenantBridge;
        networkConfig = {
          DHCP = "no";
          LinkLocalAddressing = "no";
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "no";
      };
    };
  };

  # Keep sysctl paths present, then ensure bridged tenant frames do not run
  # through Leviathan's host firewall.
  boot.kernelModules = [ "br_netfilter" ];
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 0;
    "net.bridge.bridge-nf-call-ip6tables" = 0;
    "net.bridge.bridge-nf-call-arptables" = 0;
  };
}
