{
  config,
  inputs,
  self,
  pkgs,
  ...
}:
let
  machineName = config.clan.core.settings.machine.name or config.networking.hostName;
  tenant =
    self.compute.tenants.${machineName} or (throw "No tenant VM inventory entry for ${machineName}");
  plan = self.compute.plans.${tenant.plan} or (throw "Unknown tenant VM plan ${tenant.plan}");
  hostId = builtins.substring 0 8 (builtins.replaceStrings [ "-" ] [ "" ] config.microvm.machineId);
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
    hypervisor = "qemu";
    inherit (plan) vcpu;
    mem = plan.memoryMiB;

    interfaces = [
      {
        type = "tap";
        id = tapId;
        inherit (tenant) mac;
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
    ++ map (volume: {
      image = "${volume.name}.img";
      inherit (volume) mountPoint;
      size = volume.sizeMiB;
    }) (tenant.volumes or [ ]);
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
