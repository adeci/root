# VM planning / research notes

This is a working document for review. It captures the current home-lab MicroVM plan, the secrets/prewarm dilemma, related research, and the options under consideration. It is intentionally broader than an implementation plan.

## Context

This repo is a Clan-based NixOS/Darwin infrastructure flake. It manages physical hosts, cloud resources, router/firewall config, and custom Clan services.

Relevant machines:

- `leviathan`: high-resource NixOS host. Runs buildbot/Harmonia/remote-builder/game/tenant workloads. Now also MicroVM substrate.
- `janus`: NixOS router/firewall/DHCP/DNS host.
- `compute-lab`: first canary MicroVM, modeled as a normal Clan/NixOS machine.

Goal for the MicroVM work:

- Build a generic compute MicroVM foundation, not a game-specific system.
- Treat hosted MicroVMs as normal Clan/NixOS machines where possible.
- Keep VM workload definition host-agnostic.
- Keep placement/host assignment separate.
- Let Janus own DHCP/DNS/firewall.
- Let Leviathan own MicroVM lifecycle/resources/bridging.
- Let Clan own machine identity/config/tags/vars.
- Allow future friend/customer workloads without giving tenants access to host or other VMs.

Non-goals / constraints:

- Do not leak secrets into the Nix store.
- Do not allow tenant writes/builds into the host `/nix/store`.
- Do not require fresh host install.
- Avoid QEMU-only lock-in if possible.
- Prefer declarative NixOS/Clan integration.
- Runtime operations may be imperative: start/stop/restart/upload/backup.
- Customer access should eventually go through a public gateway/control plane, not home port-forwarding.

## Current implemented MVP

A generic compute MicroVM MVP has been implemented and deployed locally.

New/modified repo areas:

- `inventory/compute/`
- `modules/flake-parts/compute.nix`
- `modules/microvms/host.nix`
- `modules/microvms/guest-base.nix`
- `machines/compute-lab/configuration.nix`
- `machines/janus/modules/router.nix`
- `machines/leviathan/configuration.nix`
- `flake.nix` / `flake.lock` add `microvm-nix/microvm.nix`

Important current design:

- `compute-lab` is a real `nixosConfigurations.compute-lab` machine.
- Leviathan imports `modules/microvms/host.nix`.
- Host module sets `microvm.vms.<name>.flake = self` for assigned tenants.
- MicroVM runner is built from `self.nixosConfigurations.<name>.config`.
- Guest boots already configured with its NixOS config.
- Guest root is tmpfs.
- Guest `/nix/store` is read-only host store via virtiofs.
- Guest persistent identity/state is on disk image volumes.
- Guest cannot `nix run` by default because `/nix/store` is read-only. This is intentional.

`compute-lab` inventory shape:

```nix
{
  id = 10;
  network = "tenant";
  plan = "small";
  tags = [ "tenant-vm" ];

  lifecycle = {
    autostart = false;
    restartIfChanged = false;
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

Derived identity:

- MAC: `02:00:00:40:00:10`
- IP: `10.40.0.10`
- DNS: `compute-lab.lan`
- deploy target, if used: `root@compute-lab.lan`

Network foundation:

- Leviathan trusted/admin/build link: `eno12399np0`, `10.10.0.20/24`.
- Leviathan tenant MicroVM lower link: `eno12409np1`, no host IP/routes.
- Leviathan tenant bridge: `br-tenant`, no host IP.
- Nexus VLAN tenant = 40.
- Janus VLAN 40 gateway: `10.40.0.1/24`.
- Janus DHCP/DNS derives static tenant reservations from `self.compute.tenants`.
- Janus firewall blocks tenant VLAN from trusted host/router-local networks except allowed local gateway/DNS/DHCP needs.

Current verified guest behavior:

- `compute-lab` boots.
- DHCP lease gives `10.40.0.10`.
- DNS `compute-lab.lan` works.
- SSH root works from trusted/Leviathan side.
- `/` tmpfs.
- `/nix/store` read-only virtiofs.
- `/var/lib/tenant` persistent ext4 volume.
- SSH host key persists under `/var/lib/tenant-system/ssh`.

Important bug found/fixed:

- Mounting a persistent volume at `/etc/ssh` masked NixOS-generated `/etc/ssh/sshd_config` and broke sshd.
- Fix: do not mount `/etc/ssh`; persist host keys under `/var/lib/tenant-system/ssh`.

## Original larger Leviathan reliability plan

This MicroVM work began inside a broader Leviathan reliability effort.

Still pending:

- Add zram + NVMe swapfile.
- Limit Nix/buildbot parallelism.
- Put workloads into cgroup slices:
  - `ci.slice`
  - `game.slice`
  - `tenant.slice`
- Prevent build/CI OOMs and CPU spikes from causing game/server lag.

Recommended but not yet implemented host safety config:

```nix
zramSwap = {
  enable = true;
  algorithm = "lz4";
  memoryPercent = 50;
  priority = 100;
};

boot.kernel.sysctl = {
  "vm.swappiness" = 100;
  "vm.page-cluster" = 0;
};

swapDevices = [
  {
    device = "/var/lib/swapfile";
    size = 524288; # 512 GiB
    priority = 10;
  }
];
```

Recommended Nix/buildbot caps:

```nix
nix.settings = {
  max-jobs = 16;
  cores = 8;
};

services.buildbot-nix.master = {
  evalWorkerCount = 16;
  evalMaxMemorySize = 4096;
};

services.buildbot-nix.worker.workers = 16;
```

## The current unresolved problem

The big question is secrets and prewarming.

Desired property:

- VM boots already configured with all services from NixOS config.
- Only mutable workload state lives on persistent disks.
- We avoid a second “deploy into the VM” step after provisioning.
- We want this for home lab and also for a work use case: prewarmed VMs with `sops-nix`-managed secrets.

Problem:

- `sops-nix` needs a decryption identity/key at activation time.
- That key cannot be in the Nix store or baked into a generic reusable image.
- If the VM is prewarmed from a generic pool, it may not yet know which app/tenant/secret domain it belongs to.
- If a paused/snapshotted VM already has secrets, the snapshot itself becomes secret material.
- If a generic warm pool has secrets preloaded, cloning/assignment can leak identity/secrets across tenants/workloads.

Core distinction:

- Prewarm compute/config: safe and desirable.
- Prewarm secret authorization: workload-specific and security-sensitive.

`nix`/`sops-nix` answer different questions:

- Nix answers: “what config/software should this VM run?”
- `sops-nix` answers: “given a decryption identity, where should secret files be materialized?”
- Neither answers by itself: “which fresh/prewarmed VM is allowed to receive this identity?”

## What `microvm.deploy.sshSwitch` is

`microvm.deploy.sshSwitch` is not provisioning or bootstrap. It is a hot-update helper for an already-running MicroVM.

Docs path read:

- `/home/alex/git/pi-repos/microvm-nix--microvm.nix/doc/src/ssh-deploy.md`
- `/home/alex/git/pi-repos/microvm-nix--microvm.nix/nixos-modules/microvm/ssh-deploy.nix`

Typical flow:

```bash
nix run .#nixosConfigurations.my-microvm.config.microvm.deploy.installOnHost root@host
nix run .#nixosConfigurations.my-microvm.config.microvm.deploy.sshSwitch root@my-microvm switch
```

It does:

1. SSH into guest.
2. Check running hostname matches expected hostname.
3. Import Nix closure registration into guest Nix DB.
4. Set `/nix/var/nix/profiles/system`.
5. Run `switch-to-configuration switch`.

`microvm.deploy.rebuild` combines host install + guest switch. If SSH switching is unavailable, it can fall back to host-side `systemctl restart microvm@<name>`.

For this repo:

- `sshSwitch` is optional.
- It can avoid reboot for updates.
- It is not required for the current “guest boots with full config” model.

## Research: what NixOS MicroVM users do

Local cloned repos / docs inspected:

- `microvm-nix--microvm.nix`
- `c3d2--nix-config`
- `dd-ix--nix-config`
- `oddlama--nixos-extra-modules`
- `astro--skyflake`
- `thpham--nixos-fireactions`
- `stapelberg--nix` (did not contain the blog MicroVM code)

### microvm.nix

Relevant features:

- Declarative MicroVMs via host `microvm.vms.<name> = { flake = ...; }`.
- Guest config can mount host `/nix/store` read-only via virtiofs.
- Guest config supports volumes, interfaces, hypervisor choice, vsock, etc.
- `microvm.credentialFiles` exists.
- QEMU runner maps `credentialFiles` to systemd fw_cfg credentials:

```nix
-fw_cfg name=opt/io.systemd.credentials/<name>,file=<path>
```

- Guest services can use `ImportCredential=` / `LoadCredential=`.
- microvm.nix test uses `ImportCredential = "SECRET_BOOTSTRAP_KEY"`.

Important caveat:

- `credentialFiles` currently works for QEMU only in microvm.nix.
- Cloud Hypervisor runner throws if `credentialFiles != {}`.
- Firecracker runner throws if `credentialFiles != {}`.
- Cloud Hypervisor has `cloud-hypervisor.platformOEMStrings`, including examples like `io.systemd.credential:APIKEY=supersecret`, but literal secret strings in Nix config/args are not acceptable.
- Firecracker’s native equivalent is more like MMDS metadata, not systemd credentialFiles.

### C3D2

Repo: `/home/alex/git/pi-repos/c3d2--nix-config`

Pattern:

- Many service MicroVMs are full NixOS configs.
- Each VM has `c3d2.deployment.server = "server10"` or similar.
- Host autostarts all `nixosConfigurations` assigned to it.
- QEMU + tap + virtiofs.
- Read-only host store or erofs store image depending config.
- `/etc`, `/home`, `/var` are persistent virtiofs/ZFS-backed mounts.
- Secrets are ordinary `sops-nix` inside the guest config.
- Services use paths like `config.sops.secrets."...".path`.
- Units explicitly order after `sops-install-secrets.service` where needed.
- They keep guest stateful identity/state rather than pure stateless prewarm.

Takeaway:

- Real NixOS MicroVM deployments often treat MicroVMs as normal stateful NixOS machines with persistent secret identity/state.
- Not a pure “generic VM gets all secrets at immutable boot” model.

### DD-IX

Repo: `/home/alex/git/pi-repos/dd-ix--nix-config`

Pattern:

- Custom `microvmSystem` builder.
- Many service VMs are full NixOS configs.
- Host discovers all systems marked `dd-ix.microvm` and autostarts them.
- QEMU + tap + virtiofs.
- Persistent `/etc` and `/var` virtiofs shares:

```nix
{
  source = "/var/lib/microvms/${config.networking.hostName}/etc";
  mountPoint = "/etc";
  proto = "virtiofs";
}
{
  source = "/var/lib/microvms/${config.networking.hostName}/var";
  mountPoint = "/var";
  proto = "virtiofs";
}
```

- `sops-nix` used in guest configs.

Takeaway:

- Similar to C3D2: MicroVMs are real machines with persistent state.

### oddlama nixos-extra-modules

Repo: `/home/alex/git/pi-repos/oddlama--nixos-extra-modules`

Pattern:

- Reusable “guest” abstraction over MicroVMs and NixOS containers.
- Host defines guest backend: `microvm` or `container`.
- MicroVM backend builds guest config directly under host `microvm.vms.<guest>.config`.
- QEMU/macvtap/virtiofs default.
- Supports ZFS-backed guest state.
- Uses agenix/agenix-rekey patterns elsewhere.

Takeaway:

- Clean abstraction reference for host/guest separation.
- Again not magic stateless secret injection.

### Skyflake

Repo: `/home/alex/git/pi-repos/astro--skyflake`

Pattern:

- Hyperconverged NixOS MicroVM platform.
- Users push Nix flakes over SSH/git.
- Host builds selected `nixosConfigurations` by branch name.
- Host wraps guest config with MicroVM deployment customization.
- Uses Cloud Hypervisor by default.
- Uses Nomad to schedule/run VMs.
- Uses Ceph RBD for root disks.

Relevant architecture:

- User VM config must not already contain `microvm` config.
- Platform injects MicroVM config around user’s NixOS config.
- Deployment is “git push branch per VM name”.
- VM scheduled for reboot after build.

Takeaway:

- Strong reference for separating user NixOS config from platform MicroVM wiring.
- It uses Cloud Hypervisor, so QEMU-specific credentialFiles would not fit.
- I did not find a complete secrets story.

### thpham nixos-fireactions / fireglab

Repo: `/home/alex/git/pi-repos/thpham--nixos-fireactions`

Pattern:

- Firecracker ephemeral CI runners.
- Host service gets provider credentials through `sops-nix`.
- Host mints per-runner tokens via GitHub/Gitea/GitLab APIs.
- Host spawns Firecracker VMs from OCI/containerd images.
- Host injects per-runner metadata into Firecracker MMDS at `169.254.169.254`.
- Guest runner reads metadata and registers/runs once.
- VM destroyed after job.

Example MMDS metadata:

```json
{
  "fireglab": {
    "gitlab_instance_url": "https://gitlab.example.com",
    "runner_token": "glrt-xxxxxxxxxxxx",
    "runner_id": 12345,
    "runner_name": "fireglab-pool-abc123",
    "runner_tags": "self-hosted,fireglab,linux",
    "pool_name": "default",
    "vm_id": "abc123",
    "system_id": "abc123xyz"
  }
}
```

Takeaway:

- Very cloud-like: host/control-plane owns provider credential; per-VM receives short-lived metadata/token.
- Good fit for ephemeral CI runners.
- Less directly applicable to long-lived NixOS service VMs.

## Research: what cloud providers do

Search topics:

- cloud-init metadata/user-data/config-drive
- KubeVirt cloud-init secrets
- EC2 user data vs instance profiles / Secrets Manager
- Firecracker MMDS

General cloud pattern:

1. Image contains OS/app/config, not secrets.
2. Metadata service or config drive gives boot metadata/user-data.
3. User-data is generally not considered a safe secret store.
4. VM gets runtime identity from platform:
   - EC2 instance profile / IAM role
   - GCP service account
   - Azure managed identity
   - Kubernetes service account / projected token
   - SPIFFE/SPIRE SVID
   - TPM/attestation-based identity
5. VM uses identity to fetch secrets from Secrets Manager/Vault/KMS/etc.
6. Applications start after secrets are fetched/hydrated.

KubeVirt pattern:

- VM spec can reference a Kubernetes Secret for cloud-init user-data.
- This is convenient but shifts trust to Kubernetes Secret/RBAC.

Firecracker pattern:

- MMDS is a guest-accessible metadata service.
- Often used for config/tokens/env.
- Needs per-VM network isolation and careful metadata access rules.

AWS-like best practice:

- Do not put long-lived secrets in EC2 user-data.
- Use instance profile to fetch secrets from Secrets Manager/KMS.
- Rotate secrets and use access control around secret store.

Takeaway:

- Clouds usually do not make “generic prewarmed VM already containing final secrets” the primary model.
- They prewarm image/compute/runtime, then hydrate secrets after identity/assignment.
- If secrets are present in a prewarmed snapshot, the snapshot is secret material and must be scoped/recycled accordingly.

## Options considered

### Option A: current model + guest deploy/upload for secrets

Description:

- Host declaratively builds/starts guest config.
- Secrets still delivered by `clan vars upload compute-lab` or `clan machines update compute-lab` after guest is reachable.

Pros:

- Simple.
- Uses existing Clan vars model.
- Hypervisor-agnostic.
- Treats MicroVM like normal machine.

Cons:

- Two-step bootstrap/update.
- Secret-dependent services fail until upload occurs.
- Not “warm on host boot”.
- Operationally awkward for prewarmed pool.

### Option B: QEMU `credentialFiles` inject guest age key

Description:

- Host has guest age key as host-side secret.
- Guest config sets `microvm.credentialFiles.SOPS_AGE_KEY = <host secret path>`.
- QEMU passes file through fw_cfg systemd credentials.
- Guest sets `sops.age.keyFile = "/run/credentials/@system/SOPS_AGE_KEY"`.
- Guest `sops-nix` decrypts repo-encrypted secrets at activation.

Pros:

- Secrets not in Nix store.
- No guest SSH secret upload.
- Guest boots secret-ready.
- Elegant with systemd credentials.

Cons:

- QEMU-only in microvm.nix today.
- Host must have and expose guest age key.
- Rotation requires VM restart.
- If VM is prewarmed/snapshotted after activation, snapshot contains materialized secrets.
- Feels too tied to microvm.nix implementation detail.

Additional implementation caveat in this repo:

- Because host uses `microvm.vms.<name>.flake = self`, host cannot set guest config by also setting `microvm.vms.<name>.config.microvm.credentialFiles`.
- Credential file option would need to live in the guest NixOS config, deriving host paths by convention/inventory.

### Option C: host injects individual plaintext secrets directly

Description:

- Host decrypts all guest secrets.
- Host passes individual plaintext secrets via credentials/metadata/files.
- Guest services consume them with `LoadCredential=` or similar.

Pros:

- No guest `sops-nix` identity problem.
- Works naturally with cloud metadata and short-lived tokens.

Cons:

- Pulls every guest secret into host/control-plane plaintext domain.
- Strong host/guest service coupling.
- Weak per-guest cryptographic isolation if all encrypted to host identity.
- Service modules need special host plumbing.

This seems wrong for long-lived tenant service VMs, but reasonable for ephemeral runner tokens.

### Option D: persistent guest age key/state

Description:

- Guest has persistent identity under `/var/lib/tenant-system` or similar.
- Guest uses `sops-nix` normally.
- Initial bootstrap generates/imports/registers key once.

Pros:

- Hypervisor-agnostic.
- Matches real NixOS MicroVM deployments.
- Clear mental model: VM is a machine.
- No host runtime secret injection machinery.

Cons:

- First bootstrap/key registration still exists.
- VM becomes more stateful/pet-like.
- Wiping system state requires rebootstrap.
- Does not fully solve generic prewarm pool with secrets.

### Option E: portable seed disk / config drive

Description:

- Host creates a small per-VM seed disk at runtime.
- Disk contains bootstrap identity or metadata, not in Nix store.
- Attach read-only as a block volume.
- Guest reads/mounts it early and uses the age key/token for `sops-nix`.

This is similar to cloud-init NoCloud/ConfigDrive, but can be Nix-native.

Pros:

- More hypervisor-portable than QEMU `credentialFiles`.
- Works conceptually with QEMU, Cloud Hypervisor, Firecracker.
- Secrets not in Nix store.
- Could be tmpfs-backed and generated per boot.
- Mirrors cloud config-drive pattern.

Cons:

- Need implement lifecycle/order carefully.
- Still host has bootstrap secret/token.
- If seed contains long-lived age key, same concerns as credentials.
- Guest activation ordering needs design.

This currently feels like the best local compromise if we want warm-on-host-boot without QEMU lock-in.

### Option F: metadata service / secret broker

Description:

- Host/Janus/Conduit/control-plane exposes per-VM metadata endpoint.
- Guest proves identity or receives one-time token.
- Guest fetches age key or plaintext app secrets from secret broker.
- `sops-nix` runs after bootstrap identity is available.

Pros:

- Most cloud-like.
- Hypervisor-agnostic.
- Supports dynamic assignment/prewarm pools.
- Can support short-lived credentials and rotation.
- Clean future customer-hosting control-plane model.

Cons:

- More infrastructure.
- Metadata service must be isolated per VM.
- Need strong auth: MAC/IP is not enough alone for hostile tenants.
- Need replay/reassignment story.
- More moving parts than home MVP needs.

Possible identity mechanisms:

- one-time boot token on seed disk/MMDS;
- per-VM mTLS cert;
- SPIFFE/SPIRE SVID;
- TPM/vTPM attestation;
- host attestation + VM measurement;
- orchestrator-signed token scoped to app/env/VM ID;
- network-enforced metadata service with per-TAP rules as a weaker home-lab start.

### Option G: per-workload prewarmed pool

Description:

- VMs are not generic.
- A warm pool is assigned to an app/env/tenant/secret-domain before secrets are hydrated.
- The pool may have secrets already decrypted if all VMs belong to the same domain.

Pros:

- Can meet “prewarmed with secrets” literally.
- Avoids assigning a secret-bearing VM to a different tenant/workload.
- Faster readiness.

Cons:

- Pool/snapshot is secret material.
- Rotation requires recycling/rebuilding pool.
- More capacity fragmentation.
- Not suitable for generic cross-tenant pool.

This may be the right phrasing for work: prewarm per app/env, not generic.

### Option H: generic prewarmed pool with secrets already present

Description:

- Generic pool VMs are paused/snapshotted after secrets are hydrated.
- Later assigned to arbitrary workloads/tenants.

Pros:

- Fastest possible startup.

Cons:

- Usually wrong.
- Clones may share identity/secrets.
- `/run/secrets`, env vars, app caches, DB handles, tokens can leak.
- Hard revoke/rotation story.
- Assignment boundary is unclear.

I think this should be avoided unless “generic” actually means “generic within one secret domain”.

## `sops-nix` integration thoughts

A clean `sops-nix` pattern if bootstrap identity is fetched at runtime:

```nix
sops.age.keyFile = "/run/bootstrap/age-key.txt";

systemd.services.fetch-age-key = {
  before = [ "sops-install-secrets.service" ];
  wantedBy = [ "sops-install-secrets.service" ];
  # fetch key/token from metadata/Vault/KMS/etc into /run/bootstrap/age-key.txt
};

systemd.services.sops-install-secrets = {
  after = [ "network-online.target" "fetch-age-key.service" ];
  wants = [ "network-online.target" ];
  requires = [ "fetch-age-key.service" ];
};
```

Then app units should require/order after secrets:

```nix
systemd.services.my-app = {
  after = [ "sops-install-secrets.service" ];
  requires = [ "sops-install-secrets.service" ];
};
```

Recipient scope choices:

- Per-instance recipient:
  - good for long-lived machines;
  - bad for autoscaled/prewarmed pools due to recipient churn.
- Per-app/env recipient:
  - better for pools;
  - all instances in `app-prod` can decrypt same secrets;
  - maps naturally to app/env warm pools.
- Per-tenant recipient:
  - useful when tenant isolation is primary.
- Host recipient:
  - useful if host/control-plane intentionally owns secret distribution;
  - less cryptographic separation between host and guest.

At scale, per-app/env or per-tenant recipients seem better than per-ephemeral-VM recipients.

## Shopify/work-related framing

The work problem, generalized:

- Need prewarmed VMs.
- Need `sops-nix` secrets available when app starts.
- Want VM startup/claim latency low.
- Need avoid baking secrets into images or leaking across claims.

Suggested framing:

> Prewarm image/runtime/closure up to “waiting for secret hydration”. On claim, VM obtains runtime identity, decrypts/fetches secrets, then app reaches ready.

If the requirement is truly “VM already has secrets before assignment”, then it should be:

> Prewarm pools are scoped to a secret domain: app/env/tenant. A VM from that pool can only ever serve that same domain. Snapshots and paused VMs are secret material and must be rotated/recycled with secrets.

Cloud analogy:

- EC2 image is generic-ish; instance profile grants runtime secret access.
- KubeVirt cloud-init can use Kubernetes Secret as source for userdata.
- Firecracker MMDS gives metadata/config/tokens.
- Lambda SnapStart-style systems must refresh uniqueness/secrets after restore.

Open work questions:

1. Are prewarmed VMs generic across workloads, or preassigned to one app/env?
2. Are secrets long-lived app secrets, short-lived tokens, or both?
3. Is snapshot/restore part of prewarming?
4. If snapshots are used, are `/run/secrets`, process memory, env vars, TLS sessions, DB pools, and random seeds included?
5. What identity does a prewarmed VM have before claim?
6. What prevents VM A from fetching VM B’s metadata/secrets?
7. What is the rotation/revocation story?
8. Is per-instance SOPS recipient churn acceptable?
9. Can secret scope be per app/env instead?
10. Is a secret broker/Vault/KMS already available?
11. Does `sops-nix` need to decrypt local repo files, or can services consume fetched credentials directly?

## Current instinct / recommendation

For this repo/home lab:

1. Keep current declarative MicroVM MVP.
2. Do not anchor on QEMU `credentialFiles` yet.
3. First prove normal guest update/vars path.
4. Prototype portable seed disk if warm-on-host-boot secrets are still desired.
5. Consider metadata/secret broker later if customer hosting grows.

For a larger platform / Shopify-style system:

1. Avoid generic secret-bearing warm pools.
2. Prewarm config/runtime, not final secret authorization.
3. On assignment, fetch/hydrate secrets via runtime identity.
4. If secrets must be present before assignment, scope the warm pool to one app/env/tenant and treat it as secret material.
5. Prefer per-app/env or per-tenant SOPS recipients over per-ephemeral-instance recipients.
6. Use a secret broker / platform identity system for authorization.
7. Use `sops-nix` as the in-guest materialization mechanism, not as the full authorization/control-plane mechanism.

## Concrete local next experiments

### Experiment 1: normal Clan vars path

Goal: verify current “MicroVM as normal machine” model.

Steps:

- Add tiny secret-consuming service to `compute-lab`.
- Generate/upload Clan vars for `compute-lab`.
- Confirm service reads `/run/secrets/...`.
- Confirm restart/persistence behavior.

This tests baseline but retains guest SSH/upload.

### Experiment 2: portable seed disk

Goal: avoid QEMU-only credentials.

Sketch:

- Host has per-tenant bootstrap secret/token under `/run/secrets/...`.
- Host service creates `/run/microvm-seeds/compute-lab.img` on tmpfs.
- Image contains `age-key.txt` or one-time token.
- `microvm@compute-lab` requires seed creation service.
- Guest mounts seed read-only at `/run/bootstrap` or equivalent.
- Guest sets `sops.age.keyFile = "/run/bootstrap/age-key.txt"`.
- Guest decrypts with `sops-nix` during activation.

Open questions:

- How early can the seed be mounted for `sops-nix` activation?
- Does this work equally with QEMU, Cloud Hypervisor, Firecracker in microvm.nix?
- Should seed contain long-lived age key or short-lived token to fetch age key?
- How does rotation/restart work?

### Experiment 3: metadata endpoint

Goal: cloud-like control-plane model.

Sketch:

- Per-VM metadata endpoint reachable only from that VM.
- Guest fetches bootstrap token/key.
- Token scoped to VM/app/env and short-lived.
- Guest writes key to `/run/bootstrap/age-key.txt`.
- `sops-nix` decrypts.

Open questions:

- How to enforce per-VM metadata isolation on VLAN/bridge?
- Is MAC/IP enough for home lab? Probably yes for friendly workloads, no for hostile tenants.
- Need mTLS/SPIFFE/attestation for serious tenant security.

## Notes on current local code choices

Current `modules/microvms/host.nix`:

- Imports `inputs.microvm.nixosModules.host`.
- Sets `microvm.stateDir = "/var/lib/microvms"`.
- For assigned tenants:

```nix
microvm.vms = lib.mapAttrs (_name: tenant: {
  flake = self;
  inherit (tenant.lifecycle) autostart;
  inherit (tenant.lifecycle) restartIfChanged;
}) assignedTenants;
```

- Creates tenant bridge and enslaves tenant NIC + `vm-*` TAPs.
- Disables bridge netfilter for bridged tenant frames.

Current `modules/microvms/guest-base.nix`:

- Imports `inputs.microvm.nixosModules.microvm`.
- Sets hostname/hostId/networkd/DHCP.
- Uses QEMU for MVP:

```nix
microvm.hypervisor = "qemu";
```

- Uses read-only host store:

```nix
microvm.shares = [
  {
    tag = "ro-store";
    source = "/nix/store";
    mountPoint = "/nix/.ro-store";
    proto = "virtiofs";
    readOnly = true;
  }
];
```

- Persists `/var/lib/tenant-system` and configured tenant volumes.
- Persists SSH host key under `/var/lib/tenant-system/ssh`.

Potential future cleanup:

- Make hypervisor selectable per host/tenant.
- Add assertions:
  - tenant name does not collide with static machines;
  - tenant IDs unique per network;
  - TAP ID truncation/collision guard.
- Avoid QEMU-specific assumptions if seed disk/metadata path is chosen.

## Review request

Please review for:

1. Is the model distinction right: prewarm compute/config vs prewarm secret authorization?
2. What do mature platforms do for prewarmed secret-bearing VMs?
3. Is `sops-nix` appropriate as the in-guest materializer for prewarmed VMs?
4. What identity/bootstrap pattern is safest and operationally cleanest?
5. Would you choose:
   - persistent guest identity;
   - seed disk/config-drive;
   - metadata service;
   - QEMU/systemd credentials;
   - direct host plaintext injection;
   - something else?
6. For production scale, should SOPS recipients be per-instance, per-app/env, or per-tenant?
7. If using snapshots/prewarming, what secret/runtime state must be scrubbed or refreshed after restore?
8. How should rotation and revocation work?
9. What assumptions here are wrong or too home-lab-specific?
