# Restic snapshots as clan backups list entries.
[
  .[] | {
    name: $job + "::" + (.short_id // (.id[0:12])),
    date: .time,
    hostname: .hostname,
    paths: .paths
  }
]
