# Compute MicroVM architecture, research, and progress

Status: trusted-host compute MVP proven on `compute-lab`.

This is the canonical note for the Leviathan/Janus/Clan compute MicroVM work. It consolidates the original planning notes, review feedback, seed-disk experiment, and current implementation state.

## Current conclusion

The architecture works for long-lived hosted NixOS MicroVMs:

```text
Clan machine config/tag
→ Leviathan builds guest closure
→ runtime seed disk delivers compute-lab machine age key
→ guest sops-nix decrypts Clan service secrets at boot
→ services start
→ Tailscale joins from inside the MicroVM
```

Verified result:

```text
compute-lab.lan            → 10.40.0.10
compute-lab Tailscale path → adeci-net-ephemeral auth works from inside guest
No clan vars upload into guest needed after boot
Guest config can be hot-switched with microvm.deploy.rebuild
Leviathan CI/buildbot and MicroVMs are separated into ci.slice/compute.slice
```

The local MVP is not a generic cloud yet. It is a clean trusted-host model:

- `compute-lab` is a normal Clan/NixOS machine.
- Leviathan is allowed to decrypt `compute-lab`'s machine age key.
- Leviathan generates a runtime seed disk under `/run` before VM start.
- The guest uses that key to run `sops-nix` normally.

This is good enough for homelab and long-lived friend/service VMs. A future broker/token model can replace direct host access to guest age keys without changing the broad shape.

## Vocabulary

### Substrate

Substrate = the layer that runs the VM, not the VM's own OS config.

In this repo:

```text
Clan machine        = what compute-lab is
compute inventory   = where/how compute-lab runs
Leviathan           = VM substrate host
Janus/Nexus         = network substrate
```

Guest/Clan concerns:

```text
name
tags
NixOS modules
Clan services
vars/secrets
deploy target
app services
```

Substrate concerns:

```text
host placement
vCPU/RAM allocation
TAP device
MAC/IP allocation
VLAN/network attachment
seed disk
persistent volume images
autostart/restart policy
```

This split matters because moving a VM to another host should mostly change placement/substrate data, not the guest's service config.

## Current repo model

### Clan inventory owns machine identity

`inventory/clan/machines.nix` explicitly declares `compute-lab` like other machines:

```nix
compute-lab = {
  name = "compute-lab";
  tags = [
    "adeci-net-ephemeral"
  ];
  deploy.targetHost = "root@compute-lab.lan";
};
```

Do not generate Clan machines from compute inventory. That made `compute-lab` feel special and hid normal Clan semantics.

### Compute inventory owns substrate metadata

`inventory/compute/instances/compute-lab.nix` describes how the VM is hosted:

```nix
{
  id = 10;
  network = "tenant";

  resources = {
    vcpu = 2;
    memoryMiB = 3072;
  };

  lifecycle = {
    autostart = false;
    restartIfChanged = false;
  };

  bootstrap = {
    transport = "seed-disk";
    material = "clan-machine-age-key";
  };

  volumes = [
    {
      name = "state";
      mountPoint = "/var/lib/tenant";
      sizeMiB = 8192;
    }
  ];
}
```

`inventory/compute/assignments.nix` owns placement:

```nix
{
  leviathan = [ "compute-lab" ];
}
```

`inventory/compute/hosts.nix` owns host substrate wiring, currently Leviathan's tenant bridge/NIC.

### Future reusable network backends

Current MVP uses Janus as the external DHCP/DNS/firewall authority. That is correct for this repo, but the core compute model should not become Janus-specific.

Longer term, split networking into backends:

```text
external-dhcp
  existing router owns DHCP/DNS/firewall
  this repo's Janus adapter consumes compute instance outputs

host-private-dhcp
  compute host owns a private bridge/subnet and runs dnsmasq/Kea
  useful default for a reusable standalone flake

routed-static
  host routes per-VM /32s instead of shared L2 DHCP
  stronger isolation, more plumbing

manual
  user supplies MAC/IP/DNS externally
```

Do not run a host-local DHCP server on the same L2/VLAN where Janus Kea is already serving unless pools are deliberately partitioned. For a reusable project, host-local DHCP should own a private bridge/subnet or be a clearly separate backend.

Desired future split:

```text
compute core flake
  normalizes instances
  runs MicroVMs on assigned hosts
  provides guest base/bootstrap modules
  exposes network facts

root repo adapter
  explicit Clan machines/configs
  Janus DHCP/DNS/firewall consumption
  Leviathan physical host assignment
  Clan/sops secret source
```

### Guest config is normal NixOS

`machines/compute-lab/configuration.nix` imports the generic MicroVM guest base and declares its service config like any other machine.

Important guest defaults:

- root filesystem is tmpfs;
- `/nix/store` is read-only host store via virtiofs;
- workload state lives on disk image volumes;
- system identity lives under `/var/lib/tenant-system`;
- SSH host key path is `/var/lib/tenant-system/ssh/ssh_host_ed25519_key`;
- `sops.useSystemdActivation = true` so secrets materialize after seed mount;
- `sops.age.keyFile = "/run/seed/age-key.txt"` for seed-bootstrapped guests.

Do not mount a blank volume over `/etc/ssh`; it masks NixOS-generated `sshd_config` and breaks sshd.

## Current network model

Physical/logical state:

```text
Janus
  vlan10 trusted  → 10.10.0.1/24
  vlan40 tenant   → 10.40.0.1/24

Leviathan
  eno12399np0 → trusted/admin/build link, 10.10.0.20/24
  eno12409np1 → tenant VM lower link, enslaved to br-tenant, no host IP/routes
  br-tenant   → tenant bridge, no host IP

Nexus
  tenant VLAN 40
  sfp-sfpplus3 → Leviathan trusted access
  sfp-sfpplus4 → Leviathan tenant VM access VLAN 40
```

`compute-lab` derived network identity:

```text
id: 10
MAC: 02:00:00:40:00:10
IP: 10.40.0.10
DNS: compute-lab.lan
```

Janus owns DHCP/DNS/firewall. Guests use DHCP; IPs are not hardcoded inside guests.

Verified isolation:

```text
compute-lab → 10.40.0.1 OK
compute-lab → Janus other VLAN IPs denied: 10.10.0.1, 10.20.0.1, 10.30.0.1, 10.99.0.1
compute-lab → trusted hosts denied: 10.10.0.20, 10.10.0.10
compute-lab → internet OK
```

Admin access paths:

```bash
ssh -A alex@leviathan.cymric-daggertooth.ts.net
ssh root@compute-lab.lan

ssh root@compute-lab.cymric-daggertooth.ts.net
```

Customer/public access is future work and should go through Conduit/gateway/control-plane, not home port forwarding.

## Seed-disk bootstrap

### Goal

Boot a MicroVM with full NixOS config and decrypt service secrets without a second deploy/upload into the guest.

### Current implemented flow

```text
Leviathan sops secret
  sops/secrets/compute-lab-age.key/secret
    ↓
compute-microvm-seed-compute-lab.service
    ↓
/run/microvm-seeds/compute-lab.img
    ↓
read-only MicroVM volume
    ↓
/run/seed/age-key.txt in guest
    ↓
sops-install-secrets.service
    ↓
/run/secrets/...
    ↓
Tailscale + canary service
```

Host side:

- Leviathan is explicitly granted access to `compute-lab-age.key`.
- `compute-microvm-seed-compute-lab.service` creates `/run/microvm-seeds/compute-lab.img` before `microvm@compute-lab` starts.
- `/run/microvm-seeds` is `0750 root:kvm`.
- Seed image is owned `microvm:kvm`, mode `0400`.
- Seed image is ext4 label `SEED`.
- Seed contents include `age-key.txt`, `vm-name`, and `network`.

Guest side:

- Seed image is attached read-only as an extra volume.
- `/run/seed` mounts from `/dev/disk/by-label/SEED` as read-only.
- `sops.age.keyFile = "/run/seed/age-key.txt"`.
- `sops-install-secrets.service` runs after/requires `run-seed.mount`.

Manual grant used:

```bash
clan secrets machines add-secret leviathan compute-lab-age.key
```

The key point: the seed carries `compute-lab`'s existing Clan machine age key, not a second generated key.

### Bugs found and fixed

Seed image permission bug:

```text
QEMU could not open /run/microvm-seeds/compute-lab.img: Permission denied
```

Cause: seed dir was `0700 root:root`; QEMU runs as `microvm:kvm`.

Fix: `/run/microvm-seeds` is `0750 root:kvm`; image is `0400 microvm:kvm`.

SOPS ordering bug:

```text
/run/seed mounted correctly, but no /run/secrets
```

Cause: `sops-nix` activation happened before seed mount when not using systemd activation.

Fix: `sops.useSystemdActivation = true`; order `sops-install-secrets.service` after `run-seed.mount`.

Wrong key bug:

```text
failed to decrypt ... 0 successful groups required, got 0
```

Cause: first attempt generated a separate Leviathan seed key. It did not match `compute-lab`'s SOPS recipient.

Fix: seed disk carries `compute-lab`'s actual Clan machine age key from `sops/secrets/compute-lab-age.key/secret`.

### Verified chain

On successful boot:

```text
/run/seed mounted read-only
/run/seed/age-key.txt exists
sops-install-secrets.service active/exited success
/run/secrets/vars/compute-seed-canary/token exists
compute-seed-secret-canary.service succeeds
/run/compute-seed-canary/status = ok: decrypted 65 bytes
tailscaled starts and joins tailnet
```

No `clan vars upload compute-lab` was needed after boot.

### Why seed disk instead of QEMU credentials

`microvm.credentialFiles` is elegant but currently QEMU-only in microvm.nix:

- QEMU maps credentials via `-fw_cfg name=opt/io.systemd.credentials/...`.
- Cloud Hypervisor runner rejects `credentialFiles != {}`.
- Firecracker runner rejects `credentialFiles != {}`.

Seed disk is a delivery mechanism that maps to the cloud config-drive/NoCloud pattern and should port better to QEMU, Cloud Hypervisor, Firecracker, Nomad, KubeVirt, or cloud VMs.

## Research summary

### microvm.nix

Useful primitives:

- declarative host `microvm.vms.<name>.flake = self`;
- guest full NixOS config from `nixosConfigurations.<name>`;
- QEMU/Cloud Hypervisor/Firecracker runners;
- TAP networking;
- disk volumes;
- read-only `/nix/store` sharing via virtiofs;
- `microvm.deploy.rebuild` and `microvm.deploy.sshSwitch` for guest update flows.

`microvm.deploy.sshSwitch` is hot-switching for an already-running guest. It is not bootstrap. It imports closure registration, updates the guest system profile, then runs `switch-to-configuration`.

### C3D2 and DD-IX

Both treat service MicroVMs as real NixOS machines with persistent state and ordinary in-guest secrets.

Takeaway: full NixOS MicroVMs as long-lived service machines are a normal, mature pattern. They are not magic stateless images.

### oddlama nixos-extra-modules

Good reference for a reusable guest abstraction over MicroVM/container backends and host/guest separation.

### Skyflake

Strong reference for platform wrapping user NixOS config in MicroVM deployment plumbing. Uses Cloud Hypervisor and scheduling concepts. Secrets story is not the main focus.

### fireglab / Firecracker runner patterns

Good reference for ephemeral workload runners:

```text
host owns provider credentials
host mints per-run token
VM reads token/config via metadata service
VM registers/runs once
destroy VM
```

Takeaway: good for ephemeral jobs; less directly applicable to long-lived NixOS service VMs.

### Cloud provider pattern

Mature platforms usually do:

```text
image/config without secrets
runtime identity via metadata/IAM/service account/projected token
fetch secrets from KMS/Vault/Secrets Manager
start app after hydration
```

They do not generally prewarm a generic pool with final secrets already present.

## Load-bearing insights

### Prewarm config, not unscoped secret authorization

Safe:

```text
prewarm kernel/userspace/app closure
prewarm NixOS config
prewarm VM runtime up to waiting-for-secret-hydration
```

Dangerous:

```text
generic warm pool already containing final secrets
snapshots with /run/secrets or secret-bearing process memory
clones with shared machine identity
```

If a VM/pool already contains secrets, the pool must be scoped to that secret domain: app/env/tenant. It is no longer generic.

### Separate delivery mechanism from trust root

Delivery = how bootstrap material gets into the VM:

```text
persistent disk
SSH upload
QEMU fw_cfg/systemd credentials
seed/config disk
metadata service
application fetch from broker
```

Trust root = what authorizes secret access:

```text
persistent guest age key
host-held guest age key
short-lived signed token
cloud IAM/service account
mTLS/SPIFFE identity
vTPM/attestation
```

Seed disk is delivery. It is not the trust root. Today the trust root is "Leviathan is trusted to decrypt compute-lab's machine age key." Future trust root can be "one-time seed token exchanged with broker."

### sops-nix is materializer, not authorization system

`sops-nix` answers:

```text
Given a decryption identity, materialize declared secret files at boot/switch.
```

It does not answer:

```text
Which fresh/prewarmed VM is allowed to receive this identity?
```

That belongs to host policy today and broker/IAM/PKI later.

### Recipient strategy

- Long-lived pet/service VM: per-machine recipient is fine.
- Pool by app/env: per-app/env recipient.
- Tenant-isolated hosting: per-tenant recipient.
- Generic ephemeral instance per recipient: avoid; recipient churn is bad.

## Options considered

A. Guest deploy/upload after boot.

- Simple and normal.
- Two-step; secret-dependent services fail until upload.

B. QEMU `credentialFiles`.

- Elegant delivery for QEMU.
- QEMU-only today; do not anchor architecture on it.

C. Host injects individual plaintext service secrets.

- Useful for short-lived runner tokens.
- Couples host to app secrets; wrong default for service VMs.

D. Persistent guest identity.

- Boring and correct for pets.
- Needs initial bootstrap and persistent secret state.

E. Seed/config disk.

- Best current primitive.
- Hypervisor-portable delivery seam.
- Today carries age key; future should carry token.

F. Metadata broker.

- Cloud-like future.
- Guest exchanges seed token/identity for key/credentials.
- Needed for stronger tenant/security/revocation story.

G. Scoped prewarmed pool.

- Valid if pool scope equals secret scope.
- Treat snapshots/pool disks as secret material.

H. Generic secret-bearing warm pool.

- Reject. Wrong boundary; leaks identity/secrets across claims.

## Current decisions

- Keep QEMU supported for debug/fallback; `compute-lab` currently runs on Cloud Hypervisor after successful canary testing.
- Keep `compute-lab` as explicit normal Clan machine.
- Keep compute inventory limited to substrate metadata.
- Use read-only host `/nix/store` sharing by default.
- Use disk-image volumes for mutable tenant state.
- Do not allow tenant writes/builds into host store.
- Use seed disk for boot-time secret delivery.
- Trusted-host model acceptable for now.
- Do not pursue broker until a real tenant/control-plane need exists.
- Keep `restartIfChanged = false` so Leviathan deploys do not bounce VMs unexpectedly.
- Keep canary `autostart = false`; production VMs can opt in later.
- Do not give tenant/customer VMs trusted fleet tags by default.
- `compute-lab` currently has `adeci-net-ephemeral` only because it is an admin canary for proving real Clan service secrets.
- Compute instances are normal explicit Clan machines, but their guest updates use MicroVM tooling rather than ordinary `clan machines update <guest>`.

## Runbooks

### Add a new long-lived compute VM

1. Add explicit Clan machine in `inventory/clan/machines.nix`.
2. Add substrate metadata in `inventory/compute/instances/<name>.nix`.
3. Add assignment in `inventory/compute/assignments.nix`.
4. Add `machines/<name>/configuration.nix` importing `modules/microvms/guest-base.nix` and workload modules.
5. If using `transport = "seed-disk"` and `material = "clan-machine-age-key"`, ensure machine key exists and grant host access:

   ```bash
   clan secrets machines add-secret leviathan <name>-age.key
   ```

6. Generate/fix vars for services:

   ```bash
   clan vars fix <name>
   ```

7. Deploy Janus if DHCP/DNS changed.
8. Deploy Leviathan.
9. Start/restart VM explicitly:

   ```bash
   ssh root@leviathan 'systemctl restart microvm@<name>'
   ```

### Verify seed bootstrap

```bash
ssh -A alex@leviathan.cymric-daggertooth.ts.net \
  'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@compute-lab.lan '\''
    set -euo pipefail
    findmnt /run/seed
    test -s /run/seed/age-key.txt
    systemctl --no-pager --full status sops-install-secrets compute-seed-secret-canary
    ls -l /run/secrets/vars/compute-seed-canary/token
    cat /run/compute-seed-canary/status
  '\'''
```

### Verify Tailscale service secret path

```bash
ssh root@compute-lab.cymric-daggertooth.ts.net \
  'systemctl --no-pager --full status tailscaled; tailscale status --self'
```

With the current `adeci-net-ephemeral` tag, reboots can temporarily create `compute-lab-1` style names until old ephemeral nodes age out. This is expected for the canary and not a stable identity policy.

### Hot-switch guest config

For guest-only NixOS changes, use microvm.nix's deploy wrapper:

```bash
nix run .#nixosConfigurations.compute-lab.config.microvm.deploy.rebuild -- \
  root@leviathan.cymric-daggertooth.ts.net \
  root@compute-lab.lan
```

This was tested successfully. It builds/installs the guest closure on Leviathan, SSHes into the guest, refreshes the guest Nix DB, updates `/nix/var/nix/profiles/system`, and runs `switch-to-configuration`. It does not reboot the VM.

Preferred wrapper:

```bash
nix run .#compute-vm -- switch compute-lab
```

Other helper commands:

```bash
nix run .#compute-vm -- list
nix run .#compute-vm -- info compute-lab
nix run .#compute-vm -- status compute-lab
nix run .#compute-vm -- restart compute-lab
nix run .#compute-vm -- ssh compute-lab
```

Do not use hot-switch for substrate changes. These still require Leviathan deploy plus explicit VM restart:

```text
vCPU/RAM
MAC/TAP/network
volume layout
hypervisor
seed attachment
```

### Validate repo changes

```bash
nix fmt
nix eval .#compute --json
nix eval .#nixosConfigurations.compute-lab.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.janus.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.leviathan.config.system.build.toplevel.drvPath
nix eval .#checks.x86_64-linux --json
nix build .#packages.x86_64-linux.net-plan --no-link
```

## Pending cleanup / hardening

### MicroVM foundation

- Generalize seed bootstrap beyond `compute-lab` naming.
- Add/finish assertions:
  - TAP ID truncation/collision guard for long names.
  - Optional: assert Janus-derived IP uniqueness if future networks define subnets outside Janus.
- Add docs near `inventory/compute/` explaining substrate vs Clan machine config.
- Test host key persistence after restarts.
- Decide Tailscale identity policy per compute instance:
  - ephemeral nodes are fine for canaries but can temporarily create `-1` names after reboot until old nodes age out;
  - stable MagicDNS/Tailscale identity needs persistent Tailscale state on a VM disk and probably a non-ephemeral Clan tag.
- Cloud Hypervisor canary passed for `compute-lab`: DHCP, SSH, seed disk, sops secrets, read-only `/nix/store`, persistent volumes, restart, and hot-switch all worked. Cloud Hypervisor instances get stable vsock CIDs for systemd notify. Keep QEMU available as fallback/debug path.

### Leviathan resource safety

Implemented v1:

```text
256GiB /var/lib/swapfile
nix.settings.max-jobs = 16
nix.settings.cores = 16
buildbot eval workers = 16
buildbot eval max memory = 4096 MiB
buildbot worker count = 16
ci.slice for nix-daemon/buildbot
compute.slice for MicroVM services
```

`ci.slice` is best-effort and OOM-first:

```text
CPUWeight = 100
IOWeight = 100
MemoryHigh = 96G
MemoryMax = 128G
```

`compute.slice` is the total hosted MicroVM envelope:

```text
CPUWeight = 1000
IOWeight = 1000
MemoryLow = 16G
MemoryMax = 96G
```

No zram in v1. Add it later only if swap IO/OOM behavior shows it is useful. Current tmux-managed game servers remain outside these slices until they move into MicroVMs or dedicated systemd units.

Verified after deploy:

```text
/var/lib/swapfile active at 256G
buildbot-master active in ci.slice
buildbot-worker active in ci.slice
nix-daemon active in ci.slice
microvm@compute-lab active/configured for compute.slice
```

### Load simulation

Synthetic load simulation is optional, not a blocker. The resource controls are simple cgroup limits/weights plus a swapfile, and runtime checks confirmed the units landed in the intended slices. Real confidence should come from observing normal buildbot pushes and later real workloads, not fake stress tests.

### Real workload module

Add one reusable workload module after foundation cleanup, e.g.:

```text
modules/microvms/workloads/<name>.nix
```

Keep it generic. Game hosting is one workload, not the platform identity.

### Future broker/token model

Current seed payload:

```text
age-key.txt
```

Future seed payload:

```text
one-time token
claims: vm name, tenant/app/env, network
broker CA
optional nonce/signature
```

Future boot flow:

```text
seed token → guest fetch-bootstrap-key.service → broker → age key or plaintext credentials → sops-nix/app
```

Broker properties:

- validates token signature/scope;
- tokens single-use and short-lived;
- returns only the secret domain assigned to that VM;
- revokes by refusing future requests;
- lets running VMs continue until restart/service reload.

Do not build this until the trusted-host model hits real limits.

## Snapshot/prewarm rules

If snapshots or warm pools are introduced:

Must scrub/regenerate before service start:

- `/run/secrets/`;
- `/run/credentials/`;
- `/run/bootstrap/` or `/run/seed` contents if copied;
- `/etc/machine-id` for cloned instances;
- `/var/lib/systemd/random-seed`;
- DHCP leases;
- per-instance app identity;
- SSH host keys if clones should be distinct.

Must restart/refresh in-process state:

- TLS session caches;
- DB pools;
- OAuth/IAM tokens;
- app caches holding secrets;
- anything initialized from early randomness.

Practical rule: for NixOS service VMs, prefer fast boot plus secret hydration over snapshotting unless a workload truly needs SnapStart-style latency.

## Storage direction from original Leviathan work

Immediate root stays ext4/NVMe. Do not convert root to ZFS without planned reinstall/migration.

Bulk 3×14TB HDDs:

- likely ZFS `raidz1` for bulk, if backed up;
- 3-way mirror if safety/reads matter more than capacity.

Future fast NVMe pool:

- striped mirrors for VM disks, buildbot workdirs, caches, DBs.

If ZFS becomes heavy on Leviathan, cap ARC so it does not compete unpredictably with games/CI/VMs.

## What not to forget

- The seed disk success proves boot-time delivery, not a final tenant trust model.
- The current security model trusts Leviathan.
- `adeci-net-ephemeral` on `compute-lab` is a proof tag, not a tenant default.
- The guest cannot `nix run` by design with read-only store.
- `clan machines update leviathan` updates host runner/seed plumbing; it does not necessarily hot-switch the guest.
- Accidental VM restarts are downtime; keep restarts explicit.
- The product/control-plane path should enter through Conduit/gateway, not direct home exposure.
