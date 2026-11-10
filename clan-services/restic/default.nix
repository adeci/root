_: {
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
            description = "Override Restic repository URL. Defaults to the shared B2 bucket and this machine name.";
          };

          credentialsGenerator = lib.mkOption {
            type = lib.types.str;
            default = "restic-b2-credentials";
            description = "Clan vars generator containing the Restic repository environment file.";
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
            self,
            ...
          }:
          let
            machineName = config.clan.core.settings.machine.name;
            bucket = self.resources.b2.buckets.resticBackups;
            inherit (settings) jobName;
            repository =
              if settings.repository != null then
                settings.repository
              else
                "s3:${bucket.s3Endpoint}/${bucket.name}/${machineName}";

            stateEntries = lib.attrValues config.clan.core.state;
            stateFolders = lib.unique (lib.flatten (map (state: state.folders) stateEntries));
            hasState = config.clan.core.state != { };

            runStateCommands =
              label: attr:
              lib.concatMapStringsSep "\n" (
                state:
                let
                  command = state.${attr};
                in
                lib.optionalString (command != null) ''
                  echo "Running ${label} command for ${state.name}"
                  if ! /run/current-system/sw/bin/${command}; then
                    echo "${label} command failed for ${state.name}" >&2
                    failed=1
                  fi
                ''
              ) stateEntries;

            backupPrepareCommand = lib.concatLines [
              "#!${pkgs.bash}/bin/bash"
              "set -euo pipefail"
              "failed=0"
              (runStateCommands "pre-backup" "preBackupCommand")
              ''
                if [[ "$failed" -ne 0 ]]; then
                  exit 1
                fi
              ''
            ];

            backupCleanupCommand = lib.concatLines [
              "#!${pkgs.bash}/bin/bash"
              "set -euo pipefail"
              "failed=0"
              (runStateCommands "post-backup" "postBackupCommand")
              ''
                if [[ "$failed" -ne 0 ]]; then
                  exit 1
                fi
              ''
            ];

            restoreStateManifest = pkgs.writeText "restic-state-folders.tsv" (
              lib.concatMapStringsSep "\n" (
                state: lib.concatMapStringsSep "\n" (folder: "${state.name}\t${folder}") state.folders
              ) stateEntries
            );

            runRestoreCommands =
              label: attr:
              lib.concatMapStringsSep "\n" (
                state:
                let
                  command = state.${attr};
                in
                lib.optionalString (command != null) ''
                  if state_selected ${lib.escapeShellArg state.name}; then
                    echo "Running ${label} command for ${state.name}"
                    /run/current-system/sw/bin/${command}
                  fi
                ''
              ) stateEntries;

            snapshotListFilter = pkgs.writeText "restic-snapshot-list.jq" ''
              [
                .[] | {
                  name: "${jobName}::" + (.short_id // (.id[0:12])),
                  date: .time,
                  hostname: .hostname,
                  paths: .paths
                }
              ]
            '';
          in
          {
            config = lib.mkIf hasState {
              clan.core.vars.generators.${settings.credentialsGenerator} = {
                files.env.secret = true;
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
                paths = stateFolders;
                inherit (settings) exclude;
                inherit (settings) timerConfig;
                inherit (settings) pruneOpts;
                inherit (settings) checkOpts;
                extraBackupArgs = settings.extraBackupArgs ++ [
                  "--tag clan"
                  "--tag ${machineName}"
                ];
                initialize = true;
                inhibitsSleep = true;
                environmentFile = config.clan.core.vars.generators.${settings.credentialsGenerator}.files.env.path;
                passwordFile = config.clan.core.vars.generators.${settings.passwordGenerator}.files.password.path;
                inherit backupPrepareCommand backupCleanupCommand;
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
                      | jq --from-file ${snapshotListFilter}
                  '';
                })

                (pkgs.writeShellApplication {
                  name = "restic-restore";
                  runtimeInputs = [ pkgs.coreutils ];
                  text = ''
                    if [[ "''${NAME:-}" == "" ]]; then
                      echo "No backup name given via NAME environment variable" >&2
                      exit 1
                    fi

                    snapshot="''${NAME##*::}"
                    if [[ "$snapshot" == "$NAME" ]]; then
                      echo "Backup name must look like '${jobName}::<snapshot-id>'" >&2
                      exit 1
                    fi

                    RESTORE_FOLDERS=()
                    if [[ "''${FOLDERS:-}" != "" ]]; then
                      IFS=':' read -ra RESTORE_FOLDERS <<< "''${FOLDERS}"
                    fi

                    state_selected() {
                      local state="$1"
                      local manifest_state folder requested

                      if [[ "''${#RESTORE_FOLDERS[@]}" -eq 0 ]]; then
                        return 0
                      fi

                      while IFS=$'\t' read -r manifest_state folder; do
                        [[ "$manifest_state" == "$state" ]] || continue
                        for requested in "''${RESTORE_FOLDERS[@]}"; do
                          case "$requested" in
                            "$folder"|"$folder"/*) return 0 ;;
                          esac
                        done
                      done < ${restoreStateManifest}

                      return 1
                    }

                    include_args=()
                    while IFS=$'\t' read -r state folder; do
                      state_selected "$state" || continue
                      include_args+=(--include "$folder" --include "$folder/**")
                    done < ${restoreStateManifest}

                    if [[ "''${#include_args[@]}" -eq 0 ]]; then
                      echo "No clan.core.state folders matched FOLDERS" >&2
                      exit 1
                    fi

                    ${runRestoreCommands "pre-restore" "preRestoreCommand"}

                    /run/current-system/sw/bin/restic-${jobName} restore "$snapshot" --target / "''${include_args[@]}"

                    ${runRestoreCommands "post-restore" "postRestoreCommand"}
                  '';
                })
              ];
            };
          };
      };
  };
}
