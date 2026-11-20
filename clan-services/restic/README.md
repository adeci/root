# Restic

Backs up each machine's `clan.core.state` folders with
[restic](https://restic.net), as the provider behind `clan backups create`,
`list` and `restore`.

## Roles

- `client` (NixOS only): removes the locks of runs that were cut off, runs each
  state's `preBackupCommand`, backs up all declared state folders, then runs
  each `postBackupCommand`, and forgets the snapshots `pruneOpts` no longer
  keeps. Machines without `clan.core.state` get no backup job.

## Notes

- `pruneOpts` keeps the newest snapshot of each of the last 14 days, 8 weeks,
  12 months and 3 years: about 30 after a year of backups. All of a machine's
  snapshots count as one history whatever folders each holds, so those from
  before a folder change thin out like the rest. A month's last snapshot stays
  until that month comes round again; the first snapshot stays until there are
  snapshots from three calendar years. Two jobs on one repository would thin
  each other's snapshots, so give each its own `repository`. A snapshot of
  fewer folders taken by hand counts as that day's.
- Only the repository password is generated: set the `credentials` file (for
  S3, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) with `clan vars set`.
- Restoring some folders restores every folder of their states.
  `restic-restore` runs no state commands; `clan backups restore` runs them
  around it.
- A state folder must be a real folder: restic saves a symlink without its
  target, so the backup fails on one. Services with a dynamic user keep their
  data in `/var/lib/private/<name>`; `/var/lib/<name>` is only a link.
- With `alwaysOn = false` (laptops) there's no nightly timer:
  `restic-<job>-when-due` runs hourly and after a sleep or boot that missed a
  run, and starts the backup once the newest snapshot is 20 hours old. It
  skips on battery, and waits if no network comes up within a minute, the
  network is metered per NetworkManager, or an S3 repository's server doesn't
  answer within 10 seconds; its journal says why. A repository that answers
  with an error, such as a refused key, makes the backup run and fail.
  `restic-create` still starts a backup at once. Sleep stops the backup without
  a failure, and the next run reuses what was uploaded.

## Restoring

- One file, as root on the machine: `restic-state dump latest <file> > <copy>`
  (`state` is the default `jobName`); `restic-state ls latest <folder>` lists
  what a snapshot holds.
- Every snapshot as folders, as root on the machine:
  `restic-state mount /mnt/restic`, then `/mnt/restic/snapshots/latest/` and
  the others beside it; Ctrl-C unmounts.
- A drill that touches nothing live, as root on the machine:
  `restic-state restore latest --target /tmp/drill --include <folder>` puts
  one folder under `/tmp/drill` and runs no state commands. Check what arrived,
  then delete it.
- For real, from the admin machine: `clan backups list <machine>` names the
  snapshots, and `clan backups restore <machine> restic <name>` restores one in
  place, state by state: the state's pre-restore command, its folders, then its
  post-restore command. `--service <state>` limits it to one state, such as a
  laptop's `home` after it is reinstalled and deployed.
