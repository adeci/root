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
  assignedInstanceNames = self.compute.assignments.${hostName} or [ ];
  assignedInstances = lib.genAttrs assignedInstanceNames (
    name:
    self.compute.instances.${name}
      or (throw "Unknown compute instance assignment ${name} on ${hostName}")
  );

  seedDir = "/run/microvm-seeds";
  seedSecretName = name: "compute-seed-age-${name}";
  seedAgeKeyInstances = lib.filterAttrs (
    _name: instance:
    (instance.bootstrap.transport or "none") == "seed-disk"
    && (instance.bootstrap.material or "none") == "clan-machine-age-key"
  ) assignedInstances;

  tenantInterface = computeHost.tenantInterface or "eno12409np1";
  tenantBridge = computeHost.tenantBridge or "br-tenant";
  tenantBridgeMac = computeHost.tenantBridgeMac or "02:00:00:00:fe:40";
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  microvm = {
    stateDir = "/var/lib/microvms";
    vms = lib.mapAttrs (_name: instance: {
      flake = self;
      inherit (instance.lifecycle) autostart;
      inherit (instance.lifecycle) restartIfChanged;
    }) assignedInstances;
  };

  systemd.slices.compute = {
    description = "Hosted compute MicroVM workloads";
    sliceConfig = {
      MemoryAccounting = true;
      IOAccounting = true;
      CPUWeight = 1000;
      IOWeight = 1000;
    };
  };

  sops.secrets = lib.mapAttrs' (
    name: _instance:
    lib.nameValuePair (seedSecretName name) {
      sopsFile = config.clan.core.settings.directory + "/sops/secrets/${name}-age.key/secret";
      format = "json";
      key = "data";
      mode = "0400";
    }
  ) seedAgeKeyInstances;

  systemd.tmpfiles.rules = [
    "d ${seedDir} 0750 root kvm -"
  ];

  systemd.services =
    lib.mapAttrs' (
      name: instance:
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
          printf '%s\n' ${lib.escapeShellArg instance.network} > "$tmp_dir/network"

          truncate -s 8M "$tmp_seed"
          mkfs.ext4 -q -F -L SEED -d "$tmp_dir" "$tmp_seed"
          chown microvm:kvm "$tmp_seed"
          chmod 0400 "$tmp_seed"
          mv "$tmp_seed" "$seed"
        '';
      }
    ) seedAgeKeyInstances
    // lib.mapAttrs' (
      name: _instance:
      lib.nameValuePair "microvm@${name}" (
        {
          serviceConfig.Slice = "compute.slice";
        }
        // lib.optionalAttrs (builtins.hasAttr name seedAgeKeyInstances) {
          requires = [ "compute-microvm-seed-${name}.service" ];
          after = [ "compute-microvm-seed-${name}.service" ];
        }
      )
    ) assignedInstances;

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
