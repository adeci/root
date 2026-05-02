{
  config,
  inputs,
  self,
  ...
}:
{
  imports = [ inputs.microcompute.nixosModules.guest-base ];

  microcompute.guest = {
    instanceName = config.clan.core.settings.machine.name;
    authorizedKeys = self.users.alex.sshKeys;
    # Preserve the existing persistent system volume layout/SSH host key path.
    systemStateMountPoint = "/var/lib/tenant-system";
  };
}
