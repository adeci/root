{
  config,
  pkgs,
  self,
  ...
}:
let
  inherit (self.inventory) lan;

  ftpUser = "paperless-upload";
  ftpPassivePorts = {
    from = 30000;
    to = 30010;
  };
in
{
  # The printer uploads over plaintext FTP into Paperless' consumption dir; isolated to delete when scanner transport changes.

  clan.core.vars.generators.paperless-xerox-ingest = {
    files = {
      ftp-password = {
        secret = true;
        deploy = false;
      };
      ftp-password-hash.neededFor = "users";
    };

    runtimeInputs = with pkgs; [
      mkpasswd
      pwgen
    ];

    script = ''
      pwgen -s 32 1 | tr -d '\n' > "$out/ftp-password"
      mkpasswd -s -m sha-512 < "$out/ftp-password" | tr -d '\n' > "$out/ftp-password-hash"
    '';
  };

  users.users.${ftpUser} = {
    isSystemUser = true;
    group = config.services.paperless.user;
    home = config.services.paperless.consumptionDir;
    createHome = false;
    hashedPasswordFile =
      config.clan.core.vars.generators.paperless-xerox-ingest.files.ftp-password-hash.path;
  };

  # Group-writable for the upload user, rather than writable by everyone.
  systemd.tmpfiles.settings."10-paperless".${config.services.paperless.consumptionDir}.d.mode =
    "2770";

  # vsftpd uses PAM for local logins; without this, PAM's fallback denies them.
  security.pam.services.vsftpd = { };

  services.vsftpd = {
    enable = true;
    anonymousUser = false;
    localUsers = true;
    writeEnable = true;
    chrootlocalUser = true;
    allowWriteableChroot = true;
    userlistEnable = true;
    userlistDeny = false;
    userlist = [ ftpUser ];
    localRoot = config.services.paperless.consumptionDir;

    extraConfig = ''
      check_shell=NO
      local_umask=007
      file_open_mode=0660
      pasv_enable=YES
      pasv_min_port=${toString ftpPassivePorts.from}
      pasv_max_port=${toString ftpPassivePorts.to}
    '';
  };

  # Typed firewall options can't restrict by source; raw rules admit only the printer instead of opening FTP to all.
  networking.firewall.extraCommands = ''
    ${pkgs.iptables}/bin/iptables -A nixos-fw -s ${lan.hosts.printer.ip} -p tcp --dport 21 -j ACCEPT
    ${pkgs.iptables}/bin/iptables -A nixos-fw -s ${lan.hosts.printer.ip} -p tcp --dport ${toString ftpPassivePorts.from}:${toString ftpPassivePorts.to} -j ACCEPT
  '';
  networking.firewall.extraStopCommands = ''
    ${pkgs.iptables}/bin/iptables -D nixos-fw -s ${lan.hosts.printer.ip} -p tcp --dport 21 -j ACCEPT 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -D nixos-fw -s ${lan.hosts.printer.ip} -p tcp --dport ${toString ftpPassivePorts.from}:${toString ftpPassivePorts.to} -j ACCEPT 2>/dev/null || true
  '';
}
