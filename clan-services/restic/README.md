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

## Restoring

- A drill that touches nothing live, as root on the machine:
  `restic-state restore latest --target /tmp/drill --include <folder>` puts
  one folder under `/tmp/drill` and runs no state commands (`state` is the
  default `jobName`). Check what arrived, then delete it.
- For real, from the admin machine: `clan backups list <machine>` names the
  snapshots, and `clan backups restore <machine> restic <name>` restores one in
  place and runs each state's restore commands. `--service <state>` limits it
  to one state.
