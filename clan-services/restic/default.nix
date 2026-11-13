{
  _class = "clan.service";

  manifest = {
    name = "@adeci/restic";
    description = "Restic backups for Clan-declared state";
    categories = [ "System" ];
    readme = builtins.readFile ./README.md;
  };

  roles.client = {
    description = "Machine that backs up its clan.core.state folders to object storage.";

    interface =
      { lib, ... }:
      {
        options = {
          repository = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Restic repository URL. Null means `<repositoryBase>/<machine>`.";
          };

          repositoryBase = lib.mkOption {
            type = lib.types.str;
            example = "s3:s3.example.com/restic-backups";
            description = "Repository URL prefix; each machine's repository is `<repositoryBase>/<machine>` unless `repository` is set.";
          };

          credentials = lib.mkOption {
            description = "Clan var whose file holds the repository credentials as environment variables. The service only declares the file; set it with `clan vars set <machine> <generator>/<file>`.";
            type = lib.types.submodule {
              options = {
                generator = lib.mkOption { type = lib.types.str; };
                file = lib.mkOption { type = lib.types.str; };
              };
            };
          };

          passwordGenerator = lib.mkOption {
            type = lib.types.str;
            default = "restic-password";
            description = "Clan vars generator containing the Restic repository password.";
          };

          jobName = lib.mkOption {
            type = lib.types.strMatching "^[a-zA-Z0-9._-]+$";
            default = "state";
            description = "Name for the underlying NixOS Restic job.";
          };

          timerConfig = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
            default = {
              OnCalendar = "03:00";
              RandomizedDelaySec = "2h";
              Persistent = true;
            };
            description = "systemd timerConfig for the Restic backup job. Set to null for manual-only backups.";
          };

          exclude = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Restic exclude patterns.";
          };

          pruneOpts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "--keep-daily 14"
              "--keep-weekly 8"
              "--keep-monthly 12"
              "--keep-yearly 3"
            ];
            description = "Options for restic forget --prune.";
          };

          checkOpts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Options for restic check after backup/prune. Empty disables checks after every backup.";
          };

          extraBackupArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additional arguments passed to restic backup.";
          };
        };
      };

    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            machineName = config.clan.core.settings.machine.name;
            inherit (settings) jobName;
            repository =
              if settings.repository != null then
                settings.repository
              else
                "${settings.repositoryBase}/${machineName}";

            states = lib.attrValues config.clan.core.state;

            # One "<state>\t<folder>" line per state folder.
            stateFolders = pkgs.writeText "restic-state-folders.tsv" (
              lib.concatMapStrings (
                state: lib.concatMapStrings (folder: "${state.name}\t${folder}\n") state.folders
              ) states
            );

            # One "<state>\t<hook>\t<command>" line per state command, hook being e.g. pre-backup.
            stateCommands = pkgs.writeText "restic-state-commands.tsv" (
              lib.concatMapStrings (
                state:
                let
                  commands = {
                    pre-backup = state.preBackupCommand;
                    post-backup = state.postBackupCommand;
                    pre-restore = state.preRestoreCommand;
                    post-restore = state.postRestoreCommand;
                  };
                in
                lib.concatStrings (
                  lib.mapAttrsToList (
                    hook: command: lib.optionalString (command != null) "${state.name}\t${hook}\t${command}\n"
                  ) commands
                )
              ) states
            );

            backupHooks = pkgs.writeShellApplication {
              name = "restic-backup-hooks";
              runtimeEnv.STATE_COMMANDS = stateCommands;
              text = builtins.readFile ./backup-hooks.sh;
            };
          in
          {
            config = lib.mkIf (states != [ ]) {
              clan.core.vars.generators.${settings.credentials.generator} = {
                files.${settings.credentials.file}.secret = true;
              };

              clan.core.vars.generators.${settings.passwordGenerator} = {
                files.password.secret = true;
                runtimeInputs = [ pkgs.openssl ];
                script = ''
                  openssl rand -base64 48 | tr -d '\n' > "$out/password"
                '';
              };

              services.restic.backups.${jobName} = {
                inherit repository;
                paths = lib.unique (lib.concatMap (state: state.folders) states);
                inherit (settings)
                  exclude
                  timerConfig
                  pruneOpts
                  checkOpts
                  ;
                extraBackupArgs = settings.extraBackupArgs ++ [
                  "--tag clan"
                  "--tag ${machineName}"
                ];
                initialize = true;
                inhibitsSleep = true;
                environmentFile =
                  config.clan.core.vars.generators.${settings.credentials.generator}.files.${settings.credentials.file}.path;
                passwordFile = config.clan.core.vars.generators.${settings.passwordGenerator}.files.password.path;
                backupPrepareCommand = "${lib.getExe backupHooks} pre-backup";
                backupCleanupCommand = "${lib.getExe backupHooks} post-backup";
              };

              clan.core.backups.providers.restic = {
                list = "restic-list";
                create = "restic-create";
                restore = "restic-restore";
              };

              environment.systemPackages = [
                (pkgs.writeShellApplication {
                  name = "restic-create";
                  runtimeInputs = [ config.systemd.package ];
                  text = ''
                    systemctl start restic-backups-${jobName}.service
                  '';
                })

                (pkgs.writeShellApplication {
                  name = "restic-list";
                  runtimeInputs = [ pkgs.jq ];
                  text = ''
                    /run/current-system/sw/bin/restic-${jobName} snapshots --json \
                      | jq --arg job ${jobName} --from-file ${./list.jq}
                  '';
                })

                (pkgs.writeShellApplication {
                  name = "restic-restore";
                  runtimeInputs = [ pkgs.coreutils ];
                  runtimeEnv = {
                    JOB_NAME = jobName;
                    STATE_FOLDERS = stateFolders;
                    STATE_COMMANDS = stateCommands;
                  };
                  text = builtins.readFile ./restore.sh;
                })
              ];
            };
          };
      };
  };
}
