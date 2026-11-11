# @adeci/restic

Restic backup client for machines with `clan.core.state` declarations.

The service treats `config.clan.core.state` as the source of truth:

- runs each state's `preBackupCommand`
- backs up all declared state folders
- runs each state's `postBackupCommand`
- exposes Clan backup provider commands for create/list/restore

Each machine gets its own repository: `repository` if set, otherwise
`<repositoryBase>/<machine>`.

Credentials come from Clan vars. The repository password
(`<passwordGenerator>/password`) is generated. The repository environment
(`credentials = { generator; file; }`, for example `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY` for an S3 repository) is only declared: whatever
issues the machine's storage keys sets it with
`clan vars set <machine> <generator>/<file>`.
