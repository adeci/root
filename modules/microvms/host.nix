{
  config,
  inputs,
  lib,
  pkgs,
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

  seedDir = "/run/microvm-seeds";
  seedSecretName = name: "compute-seed-age-${name}";
  seedAgeKeyTenants = lib.filterAttrs (
    _name: tenant: (tenant.bootstrap.method or "none") == "seed-age-key"
  ) assignedTenants;

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

  sops.secrets = lib.mapAttrs' (
    name: _tenant:
    lib.nameValuePair (seedSecretName name) {
      sopsFile = config.clan.core.settings.directory + "/sops/secrets/${name}-age.key/secret";
      format = "json";
      key = "data";
      mode = "0400";
    }
  ) seedAgeKeyTenants;

  systemd.tmpfiles.rules = [
    "d ${seedDir} 0750 root kvm -"
  ];

  systemd.services =
    lib.mapAttrs' (
      name: tenant:
      let
        ageKeyPath = config.sops.secrets.${seedSecretName name}.path;
        seedImage = "${seedDir}/${name}.img";
      in
      lib.nameValuePair "compute-microvm-seed-${name}" {
        description = "Build seed disk for MicroVM ${name}";
        before = [ "microvm@${name}.service" ];
        after = [
          "sops-install-secrets.service"
          "systemd-tmpfiles-setup.service"
        ];
        partOf = [ "microvm@${name}.service" ];
        restartIfChanged = false;
        path = [
          pkgs.coreutils
          pkgs.e2fsprogs
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail

          seed=${lib.escapeShellArg seedImage}
          tmp_seed="$seed.tmp"
          tmp_dir=$(mktemp -d)

          cleanup() {
            rm -rf "$tmp_dir" "$tmp_seed"
          }
          trap cleanup EXIT

          install -d -m 0750 -o root -g kvm ${lib.escapeShellArg seedDir}
          install -m 0400 ${lib.escapeShellArg ageKeyPath} "$tmp_dir/age-key.txt"
          printf '%s\n' ${lib.escapeShellArg name} > "$tmp_dir/vm-name"
          printf '%s\n' ${lib.escapeShellArg tenant.network} > "$tmp_dir/network"

          truncate -s 8M "$tmp_seed"
          mkfs.ext4 -q -F -L SEED -d "$tmp_dir" "$tmp_seed"
          chown microvm:kvm "$tmp_seed"
          chmod 0400 "$tmp_seed"
          mv "$tmp_seed" "$seed"
        '';
      }
    ) seedAgeKeyTenants
    // lib.mapAttrs' (
      name: _tenant:
      lib.nameValuePair "microvm@${name}" {
        requires = [ "compute-microvm-seed-${name}.service" ];
        after = [ "compute-microvm-seed-${name}.service" ];
      }
    ) seedAgeKeyTenants;

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
