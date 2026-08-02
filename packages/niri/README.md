# niri reload

Reload the niri config from this checkout without switching the system:

```sh
nix run .#niri-reload
```

The helper validates the KDL, confirms that its niri version matches the running
compositor, and waits for niri to report the reload result. If versions differ,
restart the niri session.

Build a candidate with an out-link to keep it for rollback or later inspection:

```sh
nix build .#niri --out-link "$HOME/.cache/niri-live/candidate"
"$HOME/.cache/niri-live/candidate/bin/niri-reload-config"
```

Use the helper from the current system:

```sh
/run/current-system/sw/bin/niri-reload-config
```

Do not run raw `load-config-file` commands while the helper runs. A
`ConfigLoaded` event does not identify its request.
