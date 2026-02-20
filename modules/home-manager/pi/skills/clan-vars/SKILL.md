---
name: clan-vars
description: Create, inspect, and manage clan vars and generators in the root repo. Use when working with secrets, passwords, API tokens, generated credentials, or any clan.core.vars configuration. Covers generator patterns, CLI commands, storage layout, and security rules.
---

# Clan Vars

## What Vars Are

Clan vars are the **declarative secret/value management system** in clan-core.
Instead of manually generating secrets and copying them around, you declare a
**generator** in your NixOS config that describes how to produce files (keys,
passwords, tokens, env files). The clan tooling runs the generator, encrypts
secrets with sops/age, and stores them in the repo.

## Security Rules

**NEVER read secret values.** Do not run `clan vars get` or read the contents
of `secret` files in `vars/`. You can:

- List vars with `clan vars list`
- Check structure with `find vars/ -type f`
- Read non-secret `value` files (like `vars/per-machine/*/state-version/version/value`)
- Look at generator definitions in Nix code

But **never** attempt to read, print, decode, or decrypt actual secret content.

## Generator Anatomy

A generator is declared at `clan.core.vars.generators.<name>` and has:

```nix
clan.core.vars.generators.my-generator = {
  # --- Prompts: interactive user input ---
  prompts.my-prompt = {
    description = "Human-readable prompt text";
    type = "hidden";        # "hidden" | "line" | "multiline" | "multiline-hidden"
    persist = true;         # If true, auto-stores prompted value as a secret file with same name
    display = {             # Optional UI hints
      group = "my-group";
      label = "My Label";
      required = true;      # false = user can skip (empty value)
      helperText = "Extra context shown next to prompt";
    };
  };

  # --- Output files ---
  files.my-secret-file = {
    secret = true;          # Default. Encrypted with sops, deployed to machine
    # Other options:
    # deploy = false;       # Generate but don't deploy (reference-only, like plaintext admin tokens)
    # owner = "myuser";     # File owner on target (default: "root")
    # group = "mygroup";    # File group (default: "root" or "wheel" on Darwin)
    # mode = "0400";        # Unix permissions (default: "0400")
    # neededFor = "services";  # When to deploy: "partitioning" | "activation" | "users" | "services"
    # restartUnits = [ "myservice.service" ];  # Restart these after deploy (sops-nix only)
  };
  files.my-public-file = {
    secret = false;         # Stored in plaintext in git, readable at eval time via .value
  };

  # --- Script: generates the files ---
  # Receives: $out (write files here), $prompts (prompted values), $in (dependency outputs)
  script = ''
    cat "$prompts/my-prompt" > "$out/my-secret-file"
    echo "public-data" > "$out/my-public-file"
  '';

  # --- Runtime dependencies for the script ---
  runtimeInputs = [ pkgs.coreutils pkgs.openssl ];

  # --- Optional settings ---
  share = false;            # If true, generated once and shared across all machines using this generator
  dependencies = [ ];       # List of other generator names; outputs available as $in/<dep>/<file>
  validation = null;        # Attrset of values; if any change, forces regeneration
};
```

## Referencing Generated Files

In NixOS config, reference the output file's **path** (runtime path on target):

```nix
services.myservice.passwordFile =
  config.clan.core.vars.generators.my-generator.files.my-secret-file.path;
```

For non-secret files, you can also read the **value** at Nix eval time:

```nix
# Only works for files with secret = false
config.clan.core.vars.generators.my-generator.files.my-public-file.value
```

Other useful attributes on a file:

- `.exists` — boolean, whether the file has been generated (non-secret only)
- `.path` — runtime path on target machine
- `.flakePath` — path in the flake source tree (for Nix-level references)

## Common Patterns in This Repo

### Prompted secret (persist pattern)

The simplest: prompt for a value, store it directly as a secret.

```nix
clan.core.vars.generators."tailscale-${instanceName}" = {
  share = true;
  files.auth_key = { };  # secret = true is default
  prompts.auth_key = {
    description = "Tailscale auth key";
    type = "hidden";
    persist = true;       # Equivalent to: script copies $prompts/auth_key to $out/auth_key
  };
  runtimeInputs = [ pkgs.coreutils ];
  script = ''
    cat "$prompts"/auth_key > "$out"/auth_key
  '';
};
```

### Generated secret (script-produces-output pattern)

Script generates the secret from inputs or randomness:

```nix
clan.core.vars.generators."vaultwarden-${instanceName}" = {
  share = true;
  files.admin_token_plaintext = { secret = true; deploy = false; };  # Keep but don't deploy
  files."vaultwarden.env" = { };  # Deployed to machine
  runtimeInputs = with pkgs; [ coreutils pwgen libargon2 ];
  script = ''
    pwgen -s 48 1 | tr -d '\n' > "$out/admin_token_plaintext"
    SALT=$(pwgen -s 32 1 | tr -d '\n')
    HASHED=$(argon2 "$SALT" -e -id -k 65540 -t 3 -p 4 < "$out/admin_token_plaintext")
    echo "ADMIN_TOKEN='$HASHED'" > "$out/vaultwarden.env"
  '';
};
```

### Password with hash (prompt-or-generate pattern)

The roster generates user passwords — prompts optionally, auto-generates if empty:

```nix
clan.core.vars.generators."user-password-${username}" = {
  share = true;
  files.user-password-hash = {
    neededFor = "users";
    restartUnits = lib.optional config.services.userborn.enable "userborn.service";
  };
  files.user-password.deploy = false;  # Reference only, not deployed
  prompts.user-password = {
    type = "hidden";
    persist = true;
    description = "Password for user ${username}";
    display = { required = false; helperText = "Leave empty to auto-generate"; };
  };
  runtimeInputs = [ pkgs.coreutils pkgs.xkcdpass pkgs.mkpasswd ];
  script = ''
    prompt_value=$(cat "$prompts"/user-password)
    if [[ -n "''${prompt_value-}" ]]; then
      echo "$prompt_value" | tr -d "\n" > "$out"/user-password
    else
      xkcdpass --numwords 4 --delimiter - --count 1 | tr -d "\n" > "$out"/user-password
    fi
    mkpasswd -s -m sha-512 < "$out"/user-password | tr -d "\n" > "$out"/user-password-hash
  '';
};
```

### Multi-secret env file (siteup pattern)

Prompt for N secrets, combine into a single env file:

```nix
clan.core.vars.generators."siteup-${name}" = {
  share = true;
  files."${name}.env" = { };
  prompts = builtins.listToAttrs (map (secretName: {
    name = secretName;
    value = { description = "Secret '${secretName}' for site '${name}'"; type = "hidden"; persist = true; };
  }) secrets);
  runtimeInputs = [ pkgs.coreutils ];
  script = let
    writeSecret = secretName: ''
      echo "${secretName}='$(cat "$prompts/${secretName}" | tr -d '\n')'" >> "$out/${name}.env"
    '';
  in ''
    ${lib.concatMapStrings writeSecret secrets}
  '';
};
```

## Storage Layout

Vars are stored in `vars/` at the repo root:

```
vars/
├── per-machine/<machine>/<generator>/<file>/
│   └── value                    # Plaintext (non-secret files only)
└── shared/<generator>/<file>/
    ├── secret                   # Sops-encrypted JSON blob
    ├── machines/<machine> → symlink to sops key
    └── users/<user> → symlink to sops key
```

- `share = true` generators → `vars/shared/<generator>/`
- `share = false` generators → `vars/per-machine/<machine>/<generator>/`
- Secret files get a `secret` file (sops-encrypted JSON) plus `machines/` and `users/` symlink dirs for key access
- Non-secret files get a `value` file with plaintext content
- Sops machine/user keys live in `sops/machines/<machine>/key.json` and `sops/users/<user>/key.json`

## CLI Commands

All commands require the devshell. Run from the repo root:

```bash
# List all vars for a machine (secrets are masked with ********)
clan vars list <machine>

# Check if vars are up to date for a machine
clan vars check <machine>
clan vars check <machine> -g <generator-name>

# Generate vars (runs generators that haven't produced output yet)
clan vars generate                          # All machines
clan vars generate <machine>                # Specific machine
clan vars generate <machine> -g <generator> # Specific generator

# Regenerate existing vars (e.g., rotate a password)
clan vars generate <machine> -g <generator> --regenerate

# Set a specific var value interactively
clan vars set <machine> <generator>/<file>

# Fix inconsistencies in the vars store
clan vars fix <machine>
clan vars fix <machine> -g <generator>

# Upload secrets to a remote machine (deploys sops private key)
clan vars upload <machine>

# Initialize sops age keys for a user
clan vars keygen
clan vars keygen --user <username>
```

## Key Rules for Writing Generators

1. **Script must produce exactly the files declared in `files`** under `$out/`.
   Missing or extra files will error.

2. **Use `share = true`** when the secret is the same across machines (API tokens,
   shared passwords). Use `share = false` (default) for per-machine values (host keys).

3. **Use `persist = true` on prompts** when you just want to store the prompted
   value directly — it's equivalent to having the script copy `$prompts/<name>`
   to `$out/<name>`.

4. **Use `deploy = false`** for files that are only needed during generation or
   for admin reference (e.g., plaintext copy of a hashed password).

5. **Use `neededFor`** to control deployment timing:
   - `"partitioning"` — before disko (encryption keys)
   - `"users"` — before user creation (password hashes)
   - `"activation"` — before nixos-rebuild
   - `"services"` — default, during normal service activation

6. **Use `runtimeInputs`** to declare packages the script needs — they'll be
   in `PATH` when the script runs.

7. **Use `dependencies`** when one generator needs output from another.
   The dependency's files appear as `$in/<dep-name>/<file-name>`.

8. **Use `validation`** to force regeneration when config values change.

9. **Generator names should be descriptive and namespaced** to the service/instance:
   `"tailscale-${instanceName}"`, `"vaultwarden-${instanceName}"`, `"user-password-${username}"`.

## Where Generators Are Defined

In this repo, generators live in **clan services** (`clan-services/`), not in
machine configs or NixOS modules directly:

| Service                    | Generator Pattern               | Purpose                 |
| -------------------------- | ------------------------------- | ----------------------- |
| `@adeci/tailscale`         | `tailscale-${instance}`         | Auth key                |
| `@adeci/vaultwarden`       | `vaultwarden-${instance}`       | Admin token + env file  |
| `@adeci/cloudflare-tunnel` | `cloudflare-token-${tokenName}` | API token               |
| `@adeci/siteup`            | `siteup-${name}`                | App secrets env file    |
| `@adeci/roster`            | `user-password-${username}`     | User passwords + hashes |

New generators for new services go in `clan-services/<service>/default.nix`.
If a generator isn't tied to a service, it can go in a machine's `configuration.nix`
or a NixOS module, but prefer the service pattern.
