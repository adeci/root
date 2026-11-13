{
  nixos =
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
      host = config.microvmHost;
      seedDirectory = "/run/microvm-seeds";
      systemctl = lib.getExe' config.systemd.package "systemctl";
      holders = lib.escapeShellArgs host.gpu.holders;

      secretsOf = name: config.microvm.vms.${name}.config.config.microvmGuest.secrets;
      seedOf = name: config.microvm.vms.${name}.config.config.microvmGuest.seed;
      generatorOf =
        name: secretName: secret:
        if secret.shared then "microvm-${secretName}" else "microvm-${name}-${secretName}";

      writeSeed =
        name:
        let
          seed = seedOf name;
          secrets = secretsOf name;
          secretFiles = host.secretFiles.${name};
        in
        pkgs.writeShellApplication {
          name = "microvm-${name}-seed";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.e2fsprogs
          ];
          runtimeEnv = {
            VM_NAME = name;
            SEED_DIRECTORY = seedDirectory;
            SEED_IMAGE = seed.image;
            SEED_LABEL = seed.label;
            SEED_SIZE_MIB = seed.sizeMiB;
            # Bash associative arrays, keyed by secret name.
            SECRET_FILES = secretFiles;
            SECRET_SEED_PATHS = lib.mapAttrs (secretName: _: secrets.${secretName}.seedPath) secretFiles;
          };
          text = builtins.readFile ./write-seed.sh;
        };

      # Both take the GPU's PCI address.
      releaseGpu = pkgs.writeShellApplication {
        name = "microvm-release-gpu";
        runtimeInputs = [
          config.systemd.package
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnused
          pkgs.procps
        ];
        runtimeEnv = {
          GPU_HOST_DRIVER = host.gpu.hostDriver;
          GPU_HOLDERS = host.gpu.holders;
        };
        text = builtins.readFile ./release-gpu.sh;
      };

      reclaimGpu = pkgs.writeShellApplication {
        name = "microvm-reclaim-gpu";
        runtimeInputs = [
          config.systemd.package
          pkgs.coreutils
        ];
        runtimeEnv = {
          GPU_HOST_DRIVER = host.gpu.hostDriver;
          GPU_HOLDERS = host.gpu.holders;
        };
        text = builtins.readFile ./reclaim-gpu.sh;
      };

      wake = pkgs.writers.writePython3 "microvm-wake" { } (builtins.readFile ./wake.py);
      wakeOnLanPort = 9;
      vmByMac = lib.mapAttrsToList (name: vm: "${vm.mac}=${name}") host.vms;
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
                self.modules.nixos.microvm-guest
                vm.config
              ];
              microvmGuest.seed.image = "${seedDirectory}/${name}.img";
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
          }) host.vms;

          systemd = {
            network.networks."10-microvm-taps" = {
              matchConfig.Name = map (name: "vm-${name}") (lib.attrNames host.vms);
              networkConfig.Bridge = host.bridge;
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
                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      ExecStart = lib.getExe (writeSeed name);
                      ExecStop = "${pkgs.coreutils}/bin/rm -f ${(seedOf name).image}";
                    };
                  };

                  "microvm@${name}".serviceConfig = {
                    Slice = "microvm.slice";
                    Restart = "no";
                    # Skip microvm.nix's shutdown when the guest already powered off; it would wait on an empty $MAINPID and fail the unit.
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
                      ExecStartPre = [ "${lib.getExe releaseGpu} ${vm.gpu}" ];
                      ExecStartPost = lib.optional (holders != "") "-${systemctl} start ${holders}";
                      # However the VM ends, even if it fails before starting.
                      ExecStopPost = [ "${lib.getExe reclaimGpu} ${vm.gpu}" ];
                    };
                  };
                }
              ) host.vms
            );
          };
        }

        (lib.mkIf (host.wakeOnLan != [ ]) {
          networking.firewall.interfaces = lib.genAttrs host.wakeOnLan (_: {
            allowedUDPPorts = [ wakeOnLanPort ];
          });
          systemd.services.microvm-wake = {
            wantedBy = [ "multi-user.target" ];
            serviceConfig.ExecStart = "${wake} ${toString wakeOnLanPort} ${toString vmByMac}";
          };
        })

        (lib.optionalAttrs (options ? clan) {
          clan.core.vars.generators = lib.listToAttrs (
            lib.concatLists (
              lib.mapAttrsToList (
                name: _:
                lib.mapAttrsToList (
                  secretName: secret:
                  lib.nameValuePair (generatorOf name secretName secret) {
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
                ) (secretsOf name)
              ) host.vms
            )
          );

          microvmHost.secretFiles = lib.mapAttrs (
            name: _:
            lib.mapAttrs (
              secretName: secret:
              config.clan.core.vars.generators.${generatorOf name secretName secret}.files.value.path
            ) (secretsOf name)
          ) host.vms;
        })
      ];
    };
}
