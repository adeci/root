{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  scanUser = "xerox-scans";
  scanGroup = scanUser;
  scanDir = "/srv/xerox-scans";
  stateDir = "/var/lib/xerox-scans";
  filebrowserDb = "${stateDir}/filebrowser.db";
  filebrowserPort = 8385;
  inherit (self.resources) homelan;
  printerIp = homelan.hosts.printer.ip;
  filebrowserUsers = [
    "alex"
    "yelena"
  ];
  passwordFile = user: "filebrowser-password-${user}";
in
{
  # Xerox WorkCentre scan target + private browser UI.
  # Printer writes via SMB. Humans manage/download scans via File Browser.

  users.groups.${scanGroup} = { };
  users.users.${scanUser} = {
    isSystemUser = true;
    group = scanGroup;
    home = scanDir;
  };
  users.users.alex.extraGroups = [ scanGroup ];

  systemd.tmpfiles.rules = [
    "d ${scanDir} 0770 ${scanUser} ${scanGroup} -"
    "d ${stateDir} 0700 ${scanUser} ${scanGroup} -"
  ];

  clan.core.state.xerox-scans.folders = [
    scanDir
    stateDir
  ];

  clan.core.vars.generators.xerox-scans = {
    files = lib.genAttrs (map passwordFile filebrowserUsers) (_: {
      secret = true;
    });
    prompts = lib.genAttrs (map passwordFile filebrowserUsers) (
      promptName:
      let
        user = lib.removePrefix "filebrowser-password-" promptName;
      in
      {
        display = {
          group = "xerox-scans";
          label = "${user} web UI password";
          required = true;
        };
        description = "Password for ${user} on the Xerox scans web UI on sequoia";
        type = "hidden";
        persist = true;
      }
    );
    runtimeInputs = [ pkgs.coreutils ];
    script = lib.concatMapStrings (user: ''
      cat "$prompts/${passwordFile user}" | tr -d '\n' > "$out/${passwordFile user}"
    '') filebrowserUsers;
  };

  services.samba = {
    enable = true;
    openFirewall = false;
    nmbd.enable = false;
    winbindd.enable = false;

    settings = {
      global = {
        security = "user";
        "server role" = "standalone server";
        "map to guest" = "Bad User";
        "guest account" = scanUser;
        "invalid users" = [ "root" ];

        # Direct-hosted SMB only. No NetBIOS browsing. This Xerox is old,
        # so allow legacy SMB/NTLM only inside the printer-only trust boundary
        # enforced below by Samba hosts allow + the host firewall.
        "disable netbios" = "yes";
        "smb ports" = "445";
        "server min protocol" = "NT1";
        "ntlm auth" = "yes";

        # Samba listens normally, but only the printer can connect:
        # firewall allows 445 from printerIp only, and Samba enforces hosts allow.
        "hosts allow" = [ printerIp ];
        "hosts deny" = [ "ALL" ];

        "load printers" = "no";
        printing = "bsd";
        "printcap name" = "/dev/null";
      };

      xerox-scans = {
        path = scanDir;
        browseable = "no";
        "read only" = "no";
        "guest ok" = "yes";
        "guest only" = "yes";
        "force user" = scanUser;
        "force group" = scanGroup;
        "create mask" = "0660";
        "directory mask" = "0770";
        "hosts allow" = [ printerIp ];
        "hosts deny" = [ "ALL" ];
      };
    };
  };

  # Firewall: SMB only from the printer IP. Web UI only LAN + Tailscale.
  networking.firewall.extraCommands = ''
    ${pkgs.iptables}/bin/iptables -A nixos-fw -i enp2s0 -s ${printerIp} -p tcp --dport 445 -j ACCEPT
  '';
  networking.firewall.extraStopCommands = ''
    ${pkgs.iptables}/bin/iptables -D nixos-fw -i enp2s0 -s ${printerIp} -p tcp --dport 445 -j ACCEPT 2>/dev/null || true
  '';
  networking.firewall.interfaces.enp2s0.allowedTCPPorts = [ 80 ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];

  systemd.services.xerox-scans-filebrowser = {
    description = "Xerox scans file browser";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    preStart = ''
      set -euo pipefail

      mkdir -p ${lib.escapeShellArg "${stateDir}/cache"}

      if [ ! -e ${lib.escapeShellArg filebrowserDb} ]; then
        ${lib.getExe pkgs.filebrowser} config init \
          --database ${lib.escapeShellArg filebrowserDb}
      fi

      ${lib.getExe pkgs.filebrowser} config set \
        --database ${lib.escapeShellArg filebrowserDb} \
        --root ${lib.escapeShellArg scanDir} \
        --address 127.0.0.1 \
        --port ${toString filebrowserPort} \
        --auth.method json \
        --branding.name ${lib.escapeShellArg "Xerox Scans"} \
        --minimumPasswordLength 8 \
        --disableExec \
        --fileMode 0660 \
        --dirMode 0770

      ${lib.concatMapStringsSep "\n" (
        user:
        let
          userArg = lib.escapeShellArg user;
        in
        ''
          password="$(cat "$CREDENTIALS_DIRECTORY/${passwordFile user}")"

          if ${lib.getExe pkgs.filebrowser} users find ${userArg} \
            --database ${lib.escapeShellArg filebrowserDb} >/dev/null 2>&1; then
            ${lib.getExe pkgs.filebrowser} users update ${userArg} \
              --database ${lib.escapeShellArg filebrowserDb} \
              --password "$password" \
              --scope / \
              --perm.admin=false \
              --perm.execute=false \
              --perm.share=false
          else
            ${lib.getExe pkgs.filebrowser} users add ${userArg} "$password" \
              --database ${lib.escapeShellArg filebrowserDb} \
              --scope / \
              --perm.admin=false \
              --perm.execute=false \
              --perm.share=false
          fi
        ''
      ) filebrowserUsers}
    '';

    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe pkgs.filebrowser)
        "--database"
        filebrowserDb
        "--root"
        scanDir
        "--address"
        "127.0.0.1"
        "--port"
        (toString filebrowserPort)
        "--disableExec"
      ];
      User = scanUser;
      Group = scanGroup;
      WorkingDirectory = scanDir;
      LoadCredential = map (
        user:
        "${passwordFile user}:${
          config.clan.core.vars.generators.xerox-scans.files.${passwordFile user}.path
        }"
      ) filebrowserUsers;
      UMask = "0007";

      NoNewPrivileges = true;
      PrivateDevices = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        scanDir
        stateDir
      ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      MemoryDenyWriteExecute = true;
      LockPersonality = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    serverTokens = false;

    virtualHosts."xerox-scans.localhost" = {
      serverAliases = [
        "scans"
        "scans.${homelan.domain}"
        "sequoia"
        "sequoia.${homelan.domain}"
      ];
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];
      extraConfig = ''
        allow 10.10.0.0/24;
        allow 100.64.0.0/10;
        deny all;
        client_max_body_size 1G;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString filebrowserPort}";
        proxyWebsockets = true;
      };
    };
  };
}
