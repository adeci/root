{
  config,
  lib,
  options,
  pkgs,
  inputs,
  self,
  ...
}:
let
  cfg = config.microvmHost;
  seedDir = "/run/microvm-seeds";
  systemctl = lib.getExe' config.systemd.package "systemctl";
  holders = lib.escapeShellArgs cfg.gpu.holders;

  secretsOf = vm: config.microvm.vms.${vm}.config.config.microvmGuest.secrets;
  generatorOf =
    vm: name: secret:
    if secret.shared then "microvm-${name}" else "microvm-${vm}-${name}";

  writeSeed =
    name:
    pkgs.writeShellScript "microvm-${name}-seed" ''
      set -eu
      seed=${seedDir}/${name}.img
      install -d -m 0750 -g kvm ${seedDir}
      tmp=$(mktemp -d -p /run)
      trap 'rm -rf "$tmp" "$seed.tmp"' EXIT
      mkdir "$tmp/secrets"
      ${lib.concatStrings (
        lib.mapAttrsToList (secret: file: ''
          install -m 0400 ${file} "$tmp/secrets/${secret}" ||
            { echo "${name}: secret ${secret} is not generated" >&2; exit 1; }
        '') cfg.secretFiles.${name}
      )}
      truncate -s 8M "$seed.tmp"
      mkfs.ext4 -q -F -L seed -d "$tmp" "$seed.tmp"
      chown microvm:kvm "$seed.tmp"
      chmod 0400 "$seed.tmp"
      mv "$seed.tmp" "$seed"
    '';

  # The NVIDIA driver blocks unbinding a GPU anything still has open, so refuse
  # instead while any process, CUDA or graphics, holds its /dev/nvidia<minor>.
  releaseGpu =
    name: gpu:
    pkgs.writeShellScript "microvm-${name}-release-gpu" ''
      set -eu
      ${lib.optionalString (holders != "") "${systemctl} stop ${holders}"}
      ${lib.optionalString (cfg.gpu.hostDriver == "nvidia") ''
        minor=$(sed -n 's/^Device Minor:[[:space:]]*//p' /proc/driver/nvidia/gpus/${gpu}/information)
        users=$(find /proc/[0-9]*/fd -lname "/dev/nvidia$minor" 2>/dev/null | cut -d/ -f3 | sort -u)
        if [ -n "$users" ]; then
          echo "${gpu} is in use by:" >&2
          ${pkgs.procps}/bin/ps -o pid=,user=,args= -p "$(echo $users | tr ' ' ,)" >&2 || true
          ${lib.optionalString (holders != "") "${systemctl} start ${holders}"}
          exit 1
        fi
      ''}
    '';

  # Gives the GPU back to the host driver unless it never left it.
  reclaimGpu =
    name: gpu:
    pkgs.writeShellScript "microvm-${name}-reclaim-gpu" ''
      set -eu
      dev=/sys/bus/pci/devices/${gpu}
      driver() { basename "$(readlink "$dev/driver" || true)"; }
      echo > "$dev/driver_override"
      if [ "$(driver)" != ${cfg.gpu.hostDriver} ]; then
        [ ! -e "$dev/driver" ] || echo ${gpu} > "$dev/driver/unbind"
        echo ${gpu} > /sys/bus/pci/drivers_probe
        [ "$(driver)" = ${cfg.gpu.hostDriver} ] ||
          { echo "${gpu} did not return to ${cfg.gpu.hostDriver}" >&2; exit 1; }
      fi
      ${lib.optionalString (holders != "") "${systemctl} restart ${holders}"}
    '';

  vmByMac = builtins.toJSON (
    lib.mapAttrs' (name: vm: lib.nameValuePair (lib.toLower vm.mac) name) cfg.vms
  );

  # Starts the VM whose MAC a magic packet (6 x 0xff, then the MAC 16 times) names.
  wake =
    pkgs.writers.writePython3 "microvm-wake"
      {
        flakeIgnore = [
          "E231"
          "E501"
        ];
      }
      ''
        import socket
        import subprocess

        vms = ${vmByMac}


        def target(packet):
            i = packet.find(b"\xff" * 6)
            mac = packet[i + 6:i + 12]
            if i >= 0 and packet[i + 6:i + 102] == mac * 16:
                return vms.get(mac.hex(":"))


        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("", 9))
        while True:
            name = target(sock.recv(1024))
            if name:
                subprocess.run(["${systemctl}", "start", "--no-block", f"microvm@{name}"])
      '';
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  options.microvmHost = {
    bridge = lib.mkOption {
      type = lib.types.str;
      description = "Bridge the VMs' taps join, isolated from each other.";
    };
    vms = lib.mkOption {
      default = { };
      description = "VMs, started on demand and left down once they exit.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            cid = lib.mkOption {
              type = lib.types.ints.between 3 65535;
              description = "vsock CID, unique on the host.";
            };
            mac = lib.mkOption { type = lib.types.str; };
            vcpu = lib.mkOption { type = lib.types.ints.positive; };
            memoryMiB = lib.mkOption { type = lib.types.ints.positive; };
            gpu = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "PCI address of a GPU to pass through.";
            };
            cpus = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Host CPUs, as for CPUAffinity=.";
            };
            volumes = lib.mkOption {
              default = { };
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    mountPoint = lib.mkOption { type = lib.types.str; };
                    sizeMiB = lib.mkOption { type = lib.types.ints.positive; };
                  };
                }
              );
            };
            config = lib.mkOption {
              type = lib.types.deferredModule;
              default = { };
            };
          };
        }
      );
    };
    secretFiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      description = "Host file of each VM secret; from clan vars on clan machines.";
    };
    gpu = {
      hostDriver = lib.mkOption {
        type = lib.types.str;
        default = "nvidia";
      };
      holders = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Units that hold every GPU; stopped while a VM takes one.";
      };
    };
    wakeOnLan = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Interfaces where a Wake-on-LAN packet for a VM's MAC starts that VM.";
    };
  };

  config = lib.mkMerge [
    {
      microvm.vms = lib.mapAttrs (name: vm: {
        autostart = false;
        restartIfChanged = false;
        specialArgs = { inherit inputs self; };
        config = {
          imports = [
            ./microvm-guest.nix
            vm.config
          ];
          microvm = {
            hypervisor = "cloud-hypervisor";
            inherit (vm) vcpu;
            mem = vm.memoryMiB;
            vsock.cid = vm.cid;
            interfaces = [
              {
                type = "tap";
                id = "vm-${name}";
                inherit (vm) mac;
              }
            ];
            devices = lib.optional (vm.gpu != null) {
              bus = "pci";
              path = vm.gpu;
            };
            volumes = lib.mapAttrsToList (label: disk: {
              image = "${label}.img";
              inherit label;
              inherit (disk) mountPoint;
              size = disk.sizeMiB;
            }) vm.volumes;
          };
        };
      }) cfg.vms;

      systemd = {
        network.networks."10-microvm-taps" = {
          matchConfig.Name = map (name: "vm-${name}") (lib.attrNames cfg.vms);
          networkConfig.Bridge = cfg.bridge;
          bridgeConfig.Isolated = true;
          linkConfig.RequiredForOnline = "no";
        };

        # VMs win CPU contention against host builds.
        slices.microvm.sliceConfig.CPUWeight = 1000;

        services = lib.mkMerge (
          lib.mapAttrsToList (
            name: vm:
            {
              "microvm-seed-${name}" = {
                requiredBy = [ "microvm@${name}.service" ];
                before = [ "microvm@${name}.service" ];
                bindsTo = [ "microvm@${name}.service" ];
                after = [ "sops-install-secrets.service" ];
                path = [ pkgs.e2fsprogs ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = writeSeed name;
                  ExecStop = "${pkgs.coreutils}/bin/rm -f ${seedDir}/${name}.img";
                };
              };

              "microvm@${name}".serviceConfig = {
                Slice = "microvm.slice";
                Restart = "no";
                # Skip microvm.nix's shutdown when the guest already powered off;
                # it would wait on an empty $MAINPID and fail the unit.
                ExecStop = [
                  ""
                  (pkgs.writeShellScript "microvm-${name}-shutdown" ''
                    [ -n "''${MAINPID:-}" ] || exit 0
                    exec ${config.microvm.stateDir}/${name}/booted/bin/microvm-shutdown
                  '')
                ];
                CPUAffinity = lib.mkIf (vm.cpus != null) vm.cpus;
              };

              "microvm-virtiofsd@${name}".serviceConfig.Slice = "microvm.slice";
            }
            // lib.optionalAttrs (vm.gpu != null) {
              "microvm-pci-devices@${name}" = {
                bindsTo = [ "microvm@${name}.service" ];
                serviceConfig = {
                  ExecStartPre = [ (releaseGpu name vm.gpu) ];
                  ExecStartPost = lib.optional (holders != "") "-${systemctl} start ${holders}";
                  # However the VM ends, even if it fails before starting.
                  ExecStopPost = [ (reclaimGpu name vm.gpu) ];
                };
              };
            }
          ) cfg.vms
        );
      };
    }

    (lib.mkIf (cfg.wakeOnLan != [ ]) {
      networking.firewall.interfaces = lib.genAttrs cfg.wakeOnLan (_: {
        allowedUDPPorts = [ 9 ];
      });
      systemd.services.microvm-wake = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = wake;
      };
    })

    (lib.optionalAttrs (options ? clan) {
      clan.core.vars.generators = lib.listToAttrs (
        lib.concatLists (
          lib.mapAttrsToList (
            vm: _:
            lib.mapAttrsToList (
              name: secret:
              lib.nameValuePair (generatorOf vm name secret) {
                files.value = { };
                prompts = lib.optionalAttrs (secret.prompt != null) {
                  value = {
                    description = secret.prompt;
                    type = "hidden";
                    persist = true;
                  };
                };
                runtimeInputs = [ pkgs.coreutils ] ++ secret.runtimeInputs;
                script = if secret.prompt != null then ''cat "$prompts/value" > "$out/value"'' else secret.script;
              }
            ) (secretsOf vm)
          ) cfg.vms
        )
      );

      microvmHost.secretFiles = lib.mapAttrs (
        vm: _:
        lib.mapAttrs (
          name: secret: config.clan.core.vars.generators.${generatorOf vm name secret}.files.value.path
        ) (secretsOf vm)
      ) cfg.vms;
    })
  ];
}
