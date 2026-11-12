{ self, ... }:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule
    base
    zsh
    llm-tools
    auto-pressure-gc
    zram
    secure-boot-luks
  ];

  # Onboard Intel NIC, needed in the initrd for SSH unlock.
  boot.initrd.availableKernelModules = [ "e1000e" ];

  secureBootLuks.initrd =
    let
      host = self.resources.homelan.hosts.clotho;
    in
    {
      macAddress = host.mac;
      address = "${host.ip}/24";
      inherit (self.resources.homelan.vlans.${host.vlan}) gateway;
      authorizedKeys = self.users.alex.sshKeys;
    };

  time.timeZone = "America/New_York";
}
