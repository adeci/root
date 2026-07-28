---
name: pexpect-cli
description: Persistent sessions for terminal programs that require ongoing interactive input, such as debuggers, REPLs, database shells, and password-prompted SSH. Do not use for one-shot SSH commands; use plain ssh instead.
---

Use `pexpect-cli` only when a command requires interactive input or terminal state must persist across calls. For ordinary remote inspection and non-interactive commands, prefer:

```bash
ssh user@host 'command'
```

Each session is a long-lived Python namespace: **all** variables, imports, and functions persist across calls.
Exceptions return exit 1 but the session stays alive. Expression results are not echoed; use `print()`.

```bash
pexpect-cli --start [--name label]   # → prints session id
pexpect-cli --list
pexpect-cli --stop <id>              # also kills spawned children

session=$(pexpect-cli --start --name ssh)
pexpect-cli $session <<'EOF'
child = pexpect.spawn('ssh user@host', encoding='utf-8')  # encoding → .before is str not bytes
child.expect('password:', timeout=30)
child.sendline('secret')
child.expect(r'\$')
EOF

# child still alive next call
pexpect-cli $session <<'EOF'
child.sendline('uptime')
child.expect(r'\$')
print(child.before)
EOF
```

When automating an interactive SSH session, avoid matching a customized shell prompt when possible. Start a predictable shell or print a unique sentinel after each command and expect that sentinel.

Only stdout is returned. stderr and full history go to `pueue log` (find task id via `pueue status --group pexpect`).

Always set `timeout=` on `expect()`. Catch `pexpect.TIMEOUT` / `pexpect.EOF` for robustness.
