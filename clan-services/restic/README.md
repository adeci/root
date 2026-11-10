# @adeci/restic

Restic backup client for machines with `clan.core.state` declarations.

The service treats `config.clan.core.state` as the source of truth:

- runs each state's `preBackupCommand`
- backs up all declared state folders
- runs each state's `postBackupCommand`
- exposes Clan backup provider commands for create/list/restore

Repository credentials are supplied through Clan vars. Terraform creates the
Backblaze B2 bucket and per-machine application keys, then writes the per-machine
S3 credentials to `restic-b2-credentials/env`.
