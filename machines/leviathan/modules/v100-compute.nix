{
  config,
  lib,
  pkgs,
  ...
}:
let
  # V100 support moved to the 580 legacy branch
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  cuda = pkgs.cudaPackages;

  dcgm = pkgs.dcgm.overrideAttrs (old: {
    # Nixpkgs already tries to skip this but the actual CTest name has the "Scenario:" prefix
    disabledTests = (old.disabledTests or [ ]) ++ [
      "Scenario: GetPluginCudalessDir returns cudaless directory in plugin directory"
    ];
  });

  dcgmExporter = (pkgs.prometheus-dcgm-exporter.override { inherit dcgm; }).overrideAttrs (old: {
    # Upstream probes /sbin/ldconfig for libdcgm.so.4
    postPatch = (old.postPatch or "") + ''
      substituteInPlace internal/pkg/prerequisites/dcgmlib_rule.go \
        --replace-fail \
          'out, err := exec.Command(ldconfigPath, ldconfigParam).Output()' \
          ' _ = ldconfigPath
          out := []byte("libdcgm.so.4 (libc6,x86-64) => ${dcgm}/lib/libdcgm.so.4\n")
          var err error'
    '';
  });

  driverLibraryPath = lib.makeLibraryPath [
    nvidiaPackage
    dcgm
    cuda.cudatoolkit
  ];
in
{
  services.xserver.videoDrivers = [ "nvidia" ];

  boot = {
    blacklistedKernelModules = [ "nouveau" ];
    kernelModules = [
      "nvidia"
      "nvidia_uvm"
    ];
  };

  hardware = {
    graphics.enable = true;

    nvidia = {
      package = nvidiaPackage;
      open = false;
      modesetting.enable = true;
      nvidiaPersistenced = true;
      nvidiaSettings = false;
      powerManagement.enable = false;
    };

    nvidia-container-toolkit.enable = true;
  };

  users.groups.dcgm = { };
  users.users.dcgm = {
    isSystemUser = true;
    group = "dcgm";
    home = "/var/lib/dcgm";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/dcgm 0750 dcgm dcgm -"
  ];

  environment = {
    systemPackages = [
      nvidiaPackage
      dcgm
      dcgmExporter
      pkgs.nvidia-container-toolkit
      pkgs.nvtopPackages.nvidia
      pkgs.pciutils
      cuda.cudatoolkit
      cuda.cudnn
      cuda.nccl
    ];

    variables = {
      # Keep CUDA indices aligned with nvidia-smi bus ordering
      CUDA_DEVICE_ORDER = "PCI_BUS_ID";
      CUDA_HOME = "${cuda.cudatoolkit}";
      CUDA_PATH = "${cuda.cudatoolkit}";
    };
  };

  programs.nix-ld.libraries = [
    nvidiaPackage
    cuda.cudatoolkit
    cuda.cudnn
    cuda.nccl
  ];

  systemd.services = {
    # DCGM is local-only, Alloy scrapes dcgm-exporter
    dcgm-hostengine = {
      description = "NVIDIA DCGM host engine";
      wantedBy = [ "multi-user.target" ];
      wants = [ "nvidia-persistenced.service" ];
      after = [ "nvidia-persistenced.service" ];
      unitConfig.ConditionPathExistsGlob = "/dev/nvidia[0-9]*";
      environment.LD_LIBRARY_PATH = "${driverLibraryPath}:/run/opengl-driver/lib";
      serviceConfig = {
        ExecStart = "${dcgm}/bin/nv-hostengine --no-daemon --bind-interface 127.0.0.1 --port 5555 --service-account dcgm --home-dir /var/lib/dcgm";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    dcgm-exporter = {
      description = "Prometheus exporter for NVIDIA DCGM metrics";
      wantedBy = [ "multi-user.target" ];
      wants = [ "dcgm-hostengine.service" ];
      after = [ "dcgm-hostengine.service" ];
      unitConfig.ConditionPathExistsGlob = "/dev/nvidia[0-9]*";
      environment.LD_LIBRARY_PATH = "${driverLibraryPath}:/run/opengl-driver/lib";
      serviceConfig = {
        ExecStart = "${dcgmExporter}/bin/dcgm-exporter --address 127.0.0.1:9400 --collectors ${pkgs.prometheus-dcgm-exporter.src}/etc/default-counters.csv --collect-interval 15000 --remote-hostengine-info 127.0.0.1:5555";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
  };
}
