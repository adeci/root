# Restic

Backs up each machine's `clan.core.state` folders with
[restic](https://restic.net), as the provider behind `clan backups create`,
`list` and `restore`.

## Roles

- `client` (NixOS only): runs each state's `preBackupCommand`, backs up all
  declared state folders, then runs each `postBackupCommand`. Machines without
  `clan.core.state` get no backup job.

## Notes

- Only the repository password is generated: set the `credentials` file (for
  S3, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) with `clan vars set`.
- Restoring some folders restores every folder of the states holding them, and
  runs only those states' restore commands.
