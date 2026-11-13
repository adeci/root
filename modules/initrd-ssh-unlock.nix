{
  nixos =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      host = self.inventory.lan.hosts.${config.networking.hostName};
      vlan = self.inventory.lan.vlans.${host.vlan};
      prefixLength = lib.last (lib.splitString "/" vlan.cidr);
    in
    {
      imports = [ self.modules.nixos.primary-user ];

      # Static so the initrd is reachable even if DHCP hands out something else.
      boot.initrd.systemd.network.networks."10-lan" = {
        matchConfig.MACAddress = host.mac;
        address = [ "${host.ip}/${prefixLength}" ];
        gateway = [ vlan.gateway ];
      };

      clan.core.vars.generators.initrd-ssh = {
        files.id_ed25519.neededFor = "activation";
        files."id_ed25519.pub".secret = false;
        runtimeInputs = [
          pkgs.coreutils
          pkgs.openssh
        ];
        script = ''
          ssh-keygen -t ed25519 -N "" -C "${config.networking.hostName}-initrd" -f "$out"/id_ed25519
        '';
      };

      # Unlock: ssh -p 2222 root@<lan ip>, then run systemd-tty-ask-password-agent.
      boot.initrd.network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys = config.system.primaryUserProfile.sshKeys;
          hostKeys = [ config.clan.core.vars.generators.initrd-ssh.files.id_ed25519.path ];
        };
      };
    };
}
