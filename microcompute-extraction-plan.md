# Microcompute extraction plan

Goal: extract the generic MicroVM substrate into a standalone flake that this repo consumes.

Current status: initial standalone repo created at `/home/alex/git/microcompute`; root consumes it as `inputs.microcompute = path:/home/alex/git/microcompute`.

The extracted project should not know about Clan, Janus, Nexus, Tailscale, Cloudflare, or this repo's inventory layout. It should consume already-built NixOS configurations and generic instance metadata.

## Current proven state

This repo has proven:

```text
Cloud Hypervisor MicroVM on Leviathan
QEMU fallback still supported
read-only host /nix/store via virtiofs
persistent disk-image volumes
TAP bridge networking through Janus VLAN
runtime seed disk
trusted-host age-key bootstrap
sops-nix decryption inside guest at boot
guest hot-switch via microvm.nix
host resource protection via ci.slice / compute.slice
operator helper: nix run .#compute-vm -- ...
```

`compute-lab` is currently the canary.

## Target project shape

Standalone repo/flake:

```text
microcompute/
  flake.nix
  modules/flake-parts/default.nix
  modules/nixos/host.nix
  modules/nixos/guest-base.nix
  modules/nixos/network/external-bridge.nix
  modules/nixos/network/host-nat-dhcp.nix
  modules/nixos/bootstrap/seed-disk.nix
  packages/compute-vm.nix
  docs/
```

Exports:

```nix
flakeModules.default
nixosModules.host
nixosModules.guest-base
packages.<system>.compute-vm
```

This repo would consume it like:

```nix
imports = [ inputs.microcompute.flakeModules.default ];

microcompute = {
  instances = import ./inventory/compute/instances;
  assignments = import ./inventory/compute/assignments;
  hosts = import ./inventory/compute/hosts;
  networks = import ./inventory/compute/networks;
};
```

Leviathan imports:

```nix
imports = [ inputs.microcompute.nixosModules.host ];
```

Guests import:

```nix
imports = [ inputs.microcompute.nixosModules.guest-base ];
```

## Core principle: consume NixOS configs, not Clan machines

Microcompute should not have a Clan integration layer.

It should assume each MicroVM instance points at a NixOS configuration in a flake:

```nix
instances.compute-lab = {
  flake = self;
  configName = "compute-lab"; # self.nixosConfigurations.compute-lab
  host = "leviathan";
  targetHost = "root@compute-lab.lan";

  hypervisor = "cloud-hypervisor";

  resources = {
    vcpu = 2;
    memoryMiB = 3072;
  };

  network = {
    backend = "external-bridge";
    name = "tenant";
    id = 10;
  };

  bootstrap = { ... };
  volumes = [ ... ];
};
```

In this repo, Clan happens to produce `self.nixosConfigurations.compute-lab`.

In another repo, plain `nixpkgs.lib.nixosSystem` could produce it. Microcompute should not care.

## What stays in this repo

This repo remains responsible for:

```text
Clan machine definitions
Clan tags/service roles/vars
Janus DHCP/DNS/firewall adapter
Leviathan physical NIC/VLAN choices
secret source wiring from Clan/sops-nix
public gateway/Conduit integration later
```

Microcompute should provide generic facts that adapters can consume:

```nix
microcompute.facts.instances.compute-lab = {
  name = "compute-lab";
  host = "leviathan";
  mac = "02:00:00:40:00:10";
  network = "tenant";
  id = 10;
  resources = { ... };
};
```

This repo's Janus module can continue deriving reservations from those facts.

## Decouple secrets

Current hardcoded behavior:

```text
host service reads:
  config.clan.core.settings.directory + /sops/secrets/<name>-age.key/secret

seed disk writes:
  /run/seed/age-key.txt

guest sops-nix uses:
  sops.age.keyFile = /run/seed/age-key.txt
```

Generic target:

```nix
bootstrap = {
  transport = "seed-disk";
  material = {
    type = "age-key-file";
    hostPath = config.sops.secrets.some-key.path;
    guestPath = "/run/seed/age-key.txt";
  };
};
```

Microcompute creates the seed disk from `hostPath`, but does not know where `hostPath` came from.

In this repo, the Leviathan adapter creates the host-side sops secret from Clan's machine age key:

```nix
sops.secrets."microcompute-age-key-compute-lab" = {
  sopsFile = config.clan.core.settings.directory + "/sops/secrets/compute-lab-age.key/secret";
  format = "json";
  key = "data";
};

microcompute.instances.compute-lab.bootstrap.material.hostPath =
  config.sops.secrets."microcompute-age-key-compute-lab".path;
```

Future broker model:

```nix
bootstrap = {
  transport = "seed-disk";
  material = {
    type = "broker-token";
    command = "mint-token --instance compute-lab";
  };
};
```

Same transport; different trust root.

## Decouple identity and deploy target

Current helper assumes Clan deploy metadata.

Generic target: `targetHost` is an instance field:

```nix
targetHost = "root@compute-lab.lan";
```

In this repo, we can set it to the same value as `inventory/clan/machines.nix`, or later derive it locally in an adapter. The generic project should not inspect Clan inventory.

## Decouple guest SSH keys

Current guest base hardcodes:

```nix
users.users.root.openssh.authorizedKeys.keys = self.users.alex.sshKeys;
```

Generic target:

```nix
microcompute.guest.authorizedKeys = [ ... ];
```

This repo passes:

```nix
microcompute.guest.authorizedKeys = self.users.alex.sshKeys;
```

Other repos pass whatever they want.

## Network attachment model

Microcompute v1 should not be a router/firewall product.

Its network responsibility should be narrow:

```text
create a dedicated Linux bridge per configured MicroVM network
plug the configured physical uplink into that bridge
create VM TAP devices
attach VM TAPs to the bridge
emit MAC/network facts for the caller
```

Out of scope for core v1:

```text
DHCP
DNS
NAT
firewall policy
public ingress
VLAN routing
```

Those belong to the user environment or optional adapters.

### ELI5 terms

```text
Linux bridge = virtual Ethernet switch
TAP device   = virtual Ethernet cable/port from the VM to the host
uplink       = physical NIC plugged into the virtual switch
```

Physical switch analogy:

```text
switch
  port 1 -> router/firewall
  port 2 -> server A
  port 3 -> server B
```

Linux bridge analogy:

```text
br-tenant
  port 1 -> eno12409np1 physical NIC/uplink
  port 2 -> vm-compute-lab TAP
  port 3 -> vm-mc-alice TAP
  port 4 -> vm-dev-bob TAP
```

Inside the VM this looks like a normal NIC (`eth0`, `ens5`, etc.). On the host, the VM's virtual cable appears as a TAP device like `vm-compute-lab`.

`br-tenant` is not magic or pre-existing. It is just the bridge name chosen in config. In v1, microcompute always creates this bridge. There is no `create = false` mode in the initial design.

### Bridge network mode

Primary v1 mode:

```nix
networks.tenant = {
  bridge = "br-tenant";
  uplink = "eno12409np1";
  bridgeMac = "02:00:00:00:fe:40"; # optional
  hostAddresses = [ ]; # default: no host IP on the bridge
};
```

This always creates:

```text
eno12409np1 -> br-tenant
VM TAPs     -> br-tenant
```

It does not create DHCP, DNS, NAT, or firewall rules.

"Plugging" the physical uplink into the bridge is the normal Linux bridge operation sometimes called enslaving an interface:

```text
before: eno12409np1 is a standalone NIC
after:  eno12409np1 is a bridge port/member of br-tenant
```

The physical NIC should not have its own DHCP/IP config while it is a bridge port. If the host needs an IP on that network, assign the IP to the bridge via `hostAddresses`; by default v1 gives the bridge no host IP.

In this repo:

```text
Nexus gives eno12409np1 untagged tenant VLAN 40
microcompute creates br-tenant and plugs eno12409np1 into it
VM TAPs plug into br-tenant
Janus sees VM MACs and gives DHCP leases
Janus owns DNS/firewall/routing
```

For another user with a home router:

```nix
networks.lan = {
  bridge = "br-vms";
  uplink = "enp3s0";
};
```

Their home router handles DHCP/DNS/firewall. VMs appear like physical machines plugged into that network.

Using an already-existing bridge can be a later escape hatch, but it is not part of v1. V1 always creates the bridge so the host-side shape is predictable.

### Isolated bridge mode

Optional/simple mode:

```nix
networks.private = {
  mode = "isolated-bridge";
  bridge = "br-microcompute";
};
```

This creates a virtual switch with no physical uplink. VMs on the same bridge can talk to each other, but nothing else routes unless the user adds routing/NAT separately.

### Future host-nat-dhcp addon

A standalone quickstart can later add an optional convenience module:

```text
create bridge
give host bridge an IP
run DHCP/DNS on the host
NAT outbound traffic
optional port forwards
```

Example future config:

```nix
networks.default = {
  mode = "host-nat-dhcp";
  bridge = "br-microcompute";
  subnet = "10.231.0.0/24";
  hostAddress = "10.231.0.1";
  dhcpRange = "10.231.0.100,10.231.0.250";
};
```

This is useful for standalone demos, but it expands microcompute from "VM attachment" into "mini router." Do not make it the core abstraction first.

### Future routed mode

Later stronger-isolation mode:

```text
host routes per-VM IPs without shared L2 DHCP
firewall can isolate VM-to-VM more cleanly
```

Not needed for extraction v1.

## Recommended network path

For extraction:

1. Implement always-create dedicated bridge mode first.
2. Move current Leviathan bridge/uplink setup into generic microcompute host module.
3. Keep this repo's Janus DHCP/DNS/firewall as an adapter consuming microcompute facts.
4. Add `isolated-bridge` later if useful.
5. Add `host-nat-dhcp` later as a standalone quickstart addon.
6. Defer routed mode and existing-bridge/manual escape hatches.

This repo should continue using bridge mode with Janus as external router/DHCP/firewall.

## In-place refactor before extraction

Do this in this repo before creating the new repo:

1. Move compute data behind options instead of direct imports.

   Current:

   ```nix
   raw = import ../../inventory/compute;
   ```

   Target:

   ```nix
   microcompute.instances = import ../../inventory/compute/instances;
   microcompute.assignments = import ../../inventory/compute/assignments;
   microcompute.hosts = import ../../inventory/compute/hosts;
   microcompute.networks = import ../../inventory/compute/networks;
   ```

2. Remove Clan assertions from the generic layer.

   Current checks:

   ```text
   explicit Clan machine exists
   machines/<name>/configuration.nix exists
   ```

   Keep these checks in this repo as local assertions or docs. Generic project should only require that a referenced NixOS configuration exists if it can check it via the provided flake.

3. Make target/deploy address explicit in compute instance metadata.

   ```nix
   targetHost = "root@compute-lab.lan";
   ```

4. Make host-side seed source explicit.

   ```nix
   bootstrap.material.hostPath = config.sops.secrets."...".path;
   ```

5. Make guest authorized keys an option.

   ```nix
   microcompute.guest.authorizedKeys = self.users.alex.sshKeys;
   ```

6. Keep Janus consumption as a root-repo adapter from microcompute facts.

7. Once all generic modules stop importing repo-local paths or Clan inventory, extraction becomes mechanical.

## Extraction steps

1. Create standalone `microcompute` repo.
2. Move generic flake-parts module, host module, guest-base module, and helper package.
3. Consume via path input from this repo.
4. Replace local imports with input imports.
5. Add `host-nat-dhcp` backend in standalone repo.
6. Add examples:

   ```text
   examples/external-bridge
   examples/host-nat-dhcp
   examples/seed-age-key
   ```

7. Only then consider broker/token and Firecracker support.

## Non-goals for extraction v1

```text
no broker yet
no confidential computing yet
no Firecracker yet
no web control panel yet
no scheduler yet
no customer billing/auth yet
```

The first standalone version should be a clean NixOS/MicroVM substrate library, not a product.
