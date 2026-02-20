# Plan: rbw for User-Level Secret Management

## Goal

Use `rbw` (unofficial Bitwarden CLI) backed by the self-hosted Vaultwarden
instance to manage user-level secrets (API tokens, session links, etc.)
instead of plaintext config files.

## Context

- Vaultwarden is already running on one of the servers (managed via
  `@adeci/vaultwarden` clan service)
- Clan vars handles system-level secrets (SSH keys, service passwords)
- User-level secrets (Kagi session link, Context7 API key, Google Maps API
  key, etc.) currently live in plaintext config files outside the repo
- Mic92 uses this exact pattern — `password_command` in config files that
  calls `rbw get <name>` at runtime

## Steps

1. **Install rbw** — add `pkgs.rbw` to the llm-tools or base-tools HM module
2. **Configure rbw** — point it at the Vaultwarden instance URL
3. **Store secrets in Vaultwarden** — add entries for:
   - `kagi-session-link`
   - `context7-api-key` (optional, works without)
   - `google-maps-api-key` (for gmaps-cli)
   - Any future API tokens
4. **Update config files** to use `password_command`:
   ```json
   // ~/.config/kagi/config.json
   {
     "password_command": "rbw get kagi-session-link"
   }
   ```
   ```json
   // ~/.config/context7/config.json
   {
     "password_command": "rbw get context7-api-key"
   }
   ```
5. **Verify** `rbw` works on all machines where `llm-tools` profile is active

## Benefits

- Secrets never in plaintext on disk (rbw caches encrypted, unlocks with
  master password)
- Same secrets available on every machine with rbw configured
- Rotation is just updating the Vaultwarden entry
- Pattern already proven by Mic92's dotfiles

## Dependencies

- Vaultwarden server accessible from all machines
- rbw package + initial `rbw register` / `rbw login` on each machine
