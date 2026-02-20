---
name: pexpect-cli
description: Persistent interactive terminal sessions for controlling SSH, databases, debuggers, or any program that expects user input. Use when you need to maintain a long-running interactive session across multiple turns.
---

# Pexpect CLI

Manage persistent interactive terminal sessions. Uses pueue as a process
manager to keep sessions alive across invocations.

## Install

```bash
nix run github:Mic92/mics-skills#pexpect-cli -- --help
```

## Usage

```bash
# Start a new session
pexpect-cli --start
# 888d9bf4

# Start with a label
pexpect-cli --start --name ssh-prod
# a3f4b2c1

# Execute code in a session
pexpect-cli 888d9bf4 <<'EOF'
child = pexpect.spawn("bash")
child.sendline("pwd")
child.expect(r"\$")
print(child.before.decode())
EOF

# List sessions
pexpect-cli --list

# Stop a session
pexpect-cli --stop 888d9bf4
```

## Examples

### SSH Session

```bash
session=$(pexpect-cli --start --name ssh-session)

pexpect-cli $session <<'EOF'
child = pexpect.spawn('ssh user@example.com')
child.expect('password:')
child.sendline('mypassword')
child.expect('\$')
print("Connected!")
EOF

# Run commands in the SSH session
pexpect-cli $session <<'EOF'
child.sendline('uptime')
child.expect('\$')
print(child.before.decode())
EOF
```

### Database Interaction

```bash
session=$(pexpect-cli --start --name db-session)

pexpect-cli $session <<'EOF'
child = pexpect.spawn('sqlite3 mydb.db')
child.expect('sqlite>')
child.sendline('.tables')
child.expect('sqlite>')
print("Tables:", child.before.decode())
EOF
```

## Available in Namespace

- `pexpect`: The pexpect module
- `child`: Persistent child process variable (persists across executions)
