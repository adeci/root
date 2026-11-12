# Restic

Backs up each machine's `clan.core.state` folders with
[restic](https://restic.net), as the provider behind `clan backups create`,
`list` and `restore`.

## Roles

- `client` (NixOS only): runs each state's `preBackupCommand`, backs up all
  declared state folders, then runs each `postBackupCommand`. Machines without
  `clan.core.state` get no backup job.

## Notes

- The repository password is generated. The `credentials` file (for example
  `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for S3) is only declared:
  set it with `clan vars set <machine> <generator>/<file>`.
