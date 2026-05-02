# Compute instances

Compute instances are hosted NixOS MicroVMs.

They are explicit Clan machines for identity, tags, vars, and NixOS config, but their runtime substrate is described here.

## Files

```text
inventory/clan/machines.nix
  Clan machine identity, tags, deploy target

machines/<name>/configuration.nix
  guest NixOS config

inventory/compute/instances/<name>.nix
  substrate metadata: network, resources, volumes, bootstrap, lifecycle

inventory/compute/assignments.nix
  host placement: host -> instance names

inventory/compute/hosts.nix
  compute host bridge/interface settings
```

## Add an instance

1. Add explicit Clan machine in `inventory/clan/machines.nix`.
2. Add `machines/<name>/configuration.nix` importing `modules/microvms/guest-base.nix`.
3. Add `inventory/compute/instances/<name>.nix`.
4. Add the instance name under a host in `inventory/compute/assignments.nix`.
5. For trusted-host seed bootstrap, grant the host access to the guest machine key:

   ```bash
   clan secrets machines add-secret leviathan <name>-age.key
   ```

6. Generate/fix vars for the guest:

   ```bash
   clan vars fix <name>
   ```

7. Deploy Janus if DHCP/DNS changed.
8. Deploy the compute host.
9. Start/restart the VM explicitly.

## Helpers

List instances:

```bash
nix run .#compute-vm -- list
```

Show metadata:

```bash
nix run .#compute-vm -- info compute-lab
```

Show host unit status:

```bash
nix run .#compute-vm -- status compute-lab
```

Start/stop/restart on the assigned host:

```bash
nix run .#compute-vm -- start compute-lab
nix run .#compute-vm -- stop compute-lab
nix run .#compute-vm -- restart compute-lab
```

Hot-switch guest NixOS config without reboot:

```bash
nix run .#compute-vm -- switch compute-lab
```

SSH to the guest deploy target:

```bash
nix run .#compute-vm -- ssh compute-lab
```

## Update model

Guest-only changes use hot-switch:

```text
packages
services
users
NixOS config inside guest
```

Substrate changes require installing/deploying the host runner plus explicit VM restart:

```text
vCPU/RAM
hypervisor
MAC/TAP/network
volume layout
seed attachment
```

Hypervisor can be selected per instance:

```nix
hypervisor = "qemu"; # default/fallback/debug
hypervisor = "cloud-hypervisor";
```

`compute-lab` has passed the Cloud Hypervisor canary: DHCP, SSH, seed disk, sops secrets, read-only `/nix/store`, persistent volumes, restart, and hot-switch.

Cloud Hypervisor instances get a stable `vsockCid` derived from the instance id by default. Override with `vsockCid = <int>;` only if needed.

## Current bootstrap model

Current trusted-host bootstrap:

```nix
bootstrap = {
  transport = "seed-disk";
  material = "age-key-file";
};
```

Leviathan decrypts the guest's Clan machine age key and writes a runtime seed disk under `/run/microvm-seeds`.

Future broker model should keep the seed-disk transport but change the material to a short-lived broker token.

## Networking

Current repo adapter uses Janus external DHCP/DNS/firewall. Do not run a second DHCP server on the same L2/VLAN.

Future reusable backends should include:

```text
external-dhcp
host-private-dhcp
routed-static
manual
```
