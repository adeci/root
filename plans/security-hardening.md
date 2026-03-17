# Security Hardening Plan

Status: planning
Hardware: 5x YubiKey 5 (NFC) incoming — 2 work, 1 USB-C (praxis),
1 micro USB-A (aegis), 1 USB-C backup (safe)

## Current State

| Layer                   | Status               | Notes                          |
| ----------------------- | -------------------- | ------------------------------ |
| Disk encryption         | ❌ None              | Plain ext4 on aegis and praxis |
| SSH keys                | Bitwarden vault      | Software-extractable           |
| Age keys                | Plain file on disk   | `~/.config/sops/age/keys.txt`  |
| Password manager        | Vaultwarden (public) | No 2FA, master password only   |
| rbw                     | ✅ Working           | Locks on suspend + 1hr timeout |
| CLI secrets (kagi etc.) | ✅ via rbw           | `rbw get kagi-session-link`    |

## Reference Setups

### Mic92

- rbw + Bitwarden, master password cached in desktop keyring (never
  retype)
- SSH keys in TPM via `ssh-tpm-agent` (unexportable)
- Age keys are plain files on disk (same as us)
- Custom `rbw-pinentry` using zenity + Python keyring library
- No lock-on-suspend for rbw (less strict than us)

### Pinpox

- passage (age-encrypted git repo) instead of rbw for desktop secrets
- PicoHSM for age private key (hardware-bound, unexportable)
- SSH via PKCS#11 through PicoHSM + TPM
- YubiKey OTP required for Vaultwarden login
- LUKS full disk encryption
- Bitwarden is browser extension only (mobile/shared passwords)

### Lassulus

- Both `bitwarden-desktop` + `rbw` + passage on desktop
- `age-detect` script that auto-discovers best hardware key:
  macOS Secure Enclave > TPM > YubiKey > Solo2
- Age identities on TPM (`age-plugin-tpm`), two YubiKeys
  (`age-plugin-yubikey`), and Solo2 (`age-plugin-fido2-hmac`)
- SSH keys via `ssh-tpm-agent` with rofi pinentry
- TPM-bound age key used for bulk decryption of passage store
- Passage store synced via git (like pinpox)

## Plan (ordered by impact)

### Phase 1: YubiKey 2FA on Vaultwarden

Difficulty: easy (10 minutes, no system changes)
Impact: huge — vault is public at `vault.decio.us` with only master
password protecting it

1. Log into `vault.decio.us` web UI
2. Settings → Security → Two-step login → Manage FIDO2 WebAuthn
3. Register all three personal YubiKeys (aegis micro USB-A, praxis
   USB-C, backup USB-C)
4. Save recovery codes (print, store in safe with backup YubiKey)
5. Test: log out, log back in — should require YubiKey tap
6. Test: `rbw login` — should prompt for 2FA

Note: 2FA is only required on new device login, not every unlock.
Mobile app will prompt once, then biometrics for daily use. "Remember
this device" option extends to 30 days.

### Phase 2: Full Disk Encryption (aegis)

Difficulty: high (requires full reinstall via disko)
Impact: critical — without this, physical access = full compromise

1. Back up everything important (home dir, any local state)
2. Update `machines/aegis/disko.nix` to use LUKS:
   ```
   partitions.luks = {
     size = "100%";
     content = {
       type = "luks";
       name = "crypted";
       settings.allowDiscards = true;
       content = {
         type = "filesystem";
         format = "ext4";
         mountpoint = "/";
       };
     };
   };
   ```
3. Reinstall via clan
4. Restore data
5. Test: reboot should prompt for LUKS passphrase

Consider: TPM-backed LUKS unlock (type passphrase only on first boot,
TPM auto-unlocks subsequent boots unless tampered with). Research
`systemd-cryptenroll --tpm2-device=auto` — but aegis only has TPM 1.2,
so this won't work here. Praxis (TPM 2.0) could do this.

### Phase 3: SSH Keys on Hardware

Difficulty: medium
Impact: high — SSH keys become unexportable

**Praxis (TPM 2.0):**

Follow Mic92/Lassulus pattern with `ssh-tpm-agent`:

1. Enable TPM2 in NixOS config (`security.tpm2.enable = true`)
2. Set up `ssh-tpm-agent` systemd user service
3. Generate TPM-bound SSH key: `ssh-tpm-keygen`
4. Add public key to GitHub, servers, etc.
5. Set `SSH_AUTH_SOCK` to tpm agent socket

**Aegis (TPM 1.2 — no ssh-tpm-agent support):**

Use YubiKey FIDO2 instead:

1. Generate key: `ssh-keygen -t ed25519-sk` (requires YubiKey plugged in)
2. This creates `~/.ssh/id_ed25519_sk` (public key handle) — the
   private key is on the YubiKey
3. Add public key to GitHub, servers, etc.
4. SSH operations require YubiKey touch

Alternative: Both machines could use YubiKey FIDO2 for consistency.
The YubiKey would then work as SSH key on either machine. TPM keys are
per-machine (non-portable). Pick based on preference:

- TPM = always available (built-in), but tied to one machine
- YubiKey = portable across machines, but must be plugged in

### Phase 4: Age Keys on YubiKey

Difficulty: medium
Impact: high — infrastructure secrets require hardware to decrypt

1. Install `age-plugin-yubikey`
2. Generate age identity on YubiKey: `age-plugin-yubikey generate`
3. Get the public key (recipient) from the output
4. Update `sops/users/alex/key.json` with the new age public key
5. Re-encrypt all sops secrets to include the new key
6. Update `~/.config/sops/age/identities` to reference the YubiKey
   plugin identity
7. Test: `sops -d sops/secrets/aegis-age.key/secret` should prompt
   for YubiKey touch
8. Keep old software age key as backup (or in the safe)

Consider: Lassulus's `age-detect` pattern — auto-discover whether
TPM or YubiKey is available. Could support both:

- Praxis: `age-plugin-tpm` (built-in, always available)
- Aegis: `age-plugin-yubikey` (must be plugged in)
- Either machine: YubiKey works as fallback on both

### Phase 5: Full Disk Encryption (praxis)

Same as Phase 2 but for praxis. With TPM 2.0, can also set up
auto-unlock via `systemd-cryptenroll --tpm2-device=auto` so daily
boots don't require passphrase (TPM unseals the key if boot chain
is untampered).

### Phase 6 (optional): Enhanced rbw Setup

Two options depending on preference:

**Option A: Mic92-style keyring caching**

- Write a custom pinentry that caches master password in GNOME Keyring
  / KDE Wallet / `secret-tool`
- Never type master password again on trusted machines
- Tradeoff: anything in your desktop session can extract it

**Option B: Keep current strict setup**

- `pinentry-curses` + lock-on-suspend (what we have now)
- Type master password after each suspend/reboot
- More secure, slightly less convenient

Current recommendation: keep Option B. The YubiKey 2FA on Vaultwarden
is the real protection. The rbw master password prompt is a minor
inconvenience that adds real defense-in-depth.

### Phase 7 (optional): passage

Adopt passage (age-encrypted password store) like pinpox/lassulus for
CLI-only secrets. This would mean:

- Bitwarden/rbw: shared passwords, mobile access, browser extension
- passage: CLI secrets (API keys, session tokens, service credentials)

Benefits: secrets are individual age-encrypted files in a git repo,
decrypted via hardware (YubiKey/TPM). No vault server dependency for
CLI tools.

This is a bigger architectural shift. Evaluate after phases 1-4 are
done and stable.

## Hardware Summary

| Machine | TPM           | YubiKey      | SSH approach               | Age approach     |
| ------- | ------------- | ------------ | -------------------------- | ---------------- |
| Aegis   | 1.2 (limited) | micro USB-A  | YubiKey FIDO2              | YubiKey          |
| Praxis  | 2.0 ✅        | USB-C        | ssh-tpm-agent (or YubiKey) | YubiKey (or TPM) |
| Mobile  | N/A           | NFC tap      | Bitwarden app              | N/A              |
| Safe    | N/A           | USB-C backup | N/A                        | Recovery         |

## Open Questions

- Do we want per-machine SSH keys (TPM on praxis, YubiKey on aegis)
  or one portable YubiKey key for both? Portable is simpler, per-machine
  is more secure (compromising one doesn't compromise the other).
- Should age identity be YubiKey-only (portable) or also have a TPM
  identity on praxis (like lassulus's age-detect pattern)?
- Investigate whether aegis is worth keeping long-term given TPM 1.2
  and Sandy Bridge limitations. If it's getting replaced, LUKS
  reinstall might not be worth the effort.
