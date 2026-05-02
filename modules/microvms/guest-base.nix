{
  config,
  inputs,
  lib,
  self,
  pkgs,
  ...
}:
let
  machineName = config.clan.core.settings.machine.name or config.networking.hostName;
  instance =
    self.compute.instances.${machineName}
      or (throw "No compute instance inventory entry for ${machineName}");
  hostId = builtins.substring 0 8 (builtins.replaceStrings [ "-" ] [ "" ] config.microvm.machineId);
  seedBootstrap =
    (instance.bootstrap.transport or "none") == "seed-disk"
    && (instance.bootstrap.material or "none") == "clan-machine-age-key";
  tapId = builtins.substring 0 15 "vm-${machineName}";
in
{
  imports = [ inputs.microvm.nixosModules.microvm ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking = {
    hostName = machineName;
    inherit hostId;
    useDHCP = false;
    useNetworkd = true;
    firewall.allowedTCPPorts = [ 22 ];
  };

  systemd.network = {
    enable = true;
    networks."10-tenant" = {
      matchConfig.Type = "ether";
      networkConfig = {
        DHCP = "ipv4";
        LinkLocalAddressing = "no";
        IPv6AcceptRA = false;
      };
      dhcpV4Config.ClientIdentifier = "mac";
      linkConfig.RequiredForOnline = "routable";
    };
  };

  microvm = {
    inherit (instance) hypervisor;
    inherit (instance.resources) vcpu;
    mem = instance.resources.memoryMiB;

    interfaces = [
      {
        type = "tap";
        id = tapId;
        inherit (instance) mac;
        tap.vhost = true;
      }
    ];

    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
        readOnly = true;
      }
    ];

    volumes = [
      {
        image = "system.img";
        mountPoint = "/var/lib/tenant-system";
        size = 256;
      }
    ]
    ++ lib.optionals seedBootstrap [
      {
        image = "/run/microvm-seeds/${machineName}.img";
        mountPoint = null;
        size = 8;
        autoCreate = false;
        readOnly = true;
      }
    ]
    ++ map (volume: {
      image = "${volume.name}.img";
      inherit (volume) mountPoint;
      size = volume.sizeMiB;
    }) (instance.volumes or [ ]);
  };

  fileSystems."/run/seed" = lib.mkIf seedBootstrap {
    device = "/dev/disk/by-label/SEED";
    fsType = "ext4";
    options = [
      "ro"
      "noatime"
    ];
  };

  sops = lib.mkIf seedBootstrap {
    useSystemdActivation = true;
    age = {
      keyFile = "/run/seed/age-key.txt";
      sshKeyPaths = [ ];
    };
  };

  systemd.services.sops-install-secrets = lib.mkIf seedBootstrap {
    after = [ "run-seed.mount" ];
    requires = [ "run-seed.mount" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/tenant-system/ssh 0700 root root -"
  ];

  users.mutableUsers = false;
  users.users.root.openssh.authorizedKeys.keys = self.users.alex.sshKeys;

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/var/lib/tenant-system/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  environment.systemPackages = [ pkgs.hello ];
}
