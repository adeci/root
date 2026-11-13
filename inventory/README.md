# Inventory

The facts about the machines and the home network, checked and published as `self.inventory`.

## How it fits together

1. **Data**: the files in this directory. `network.nix` holds the home network and the machines on it; `b2.nix`, `cloudflare.nix`, `ingress.nix`, `clan-instances.nix` and `tailscale-policy.nix` hold the rest. `users/` holds the user accounts, which `flake/users.nix` reads directly.
2. **Checks**: `flake/inventory/` reads them in. `schema.nix` types every entry in `network.nix`, `rules.nix` checks facts that span entries, and `references.nix` checks the machines and edges the other files name.
3. **Result**: `self.inventory`, the checked data with its defaults filled in and read-only values derived from it, such as `lan.hosts`, `lan.cables` and each appliance's `vlanIds`. Reading it fails while anything is wrong, listing every problem.
4. **Readers**: clan's machines and service instances (`flake/clan.nix`), the machines' own modules (`self.inventory`), the Terraform configs behind `tf-plan` and `net-plan` (`terranix/`), the netinstall apps (`flake/routeros.nix`) and the work flake (`inputs.root.inventory`). Flake-parts modules read it as `config.flake.inventory`.

Check your edits with `nix build .#checks.x86_64-linux.inventory`.

## Add a machine

```nix
machines.atlas = {
  tags = [ "adeci-net" ];
  tailnet = "100.101.102.103"; # once Tailscale has given it one
  lan = {
    mac = "aa:bb:cc:dd:ee:ff";
    ip = "10.10.0.70";
    vlan = "trusted";
  };
};
```

Leave out `lan` if it isn't on the home LAN. A Mac adds `class = "darwin"`, a laptop the `portable` tag. Reserved addresses stay outside the DHCP pool, `.100` to `.250`. The machine's configuration lives in `machines/atlas/`.

## Add a device

Something on the LAN that this repo doesn't manage:

```nix
devices.tv.lan = { mac = "aa:bb:cc:dd:ee:01"; ip = "10.20.0.30"; vlan = "iot"; };
```

Add `publishDns = false` to keep it out of the router's DNS.

## Add a cable

Write it once, on the switch port it plugs into:

```nix
appliances.nexus.ports.ether7.cable = "atlas";
```

The far end is a host (`"atlas"`), one NIC of a host (`"leviathan:eno12399np0"`), a port of another switch or access point (`"axon:sfp-sfpplus1"`) or a router port by the label on its case (`"janus:eth5"`). The port carries the switch's `defaultVlan` unless it sets `vlan`. Its label on the switch follows from the cable; set `label` only on a port with no cable recorded.

## Add a VLAN

```nix
lan.vlans.lab.id = 60;
```

That gives 10.60.0.0/24, gateway 10.60.0.1 and a DHCP pool from .100 to .250. Add it to nexus's `vlans`, since janus sends every VLAN to nexus; the rules name any other port that must carry it. Give it a forward zone in `machines/janus/modules/router/firewall.nix`. `tailnet = true` advertises it to the tailnet.

## Add a Wi-Fi network

```nix
wifi.lab = { ssid = "Lab"; vlan = "lab"; };
```

List it in the `wifi` of each access point that should broadcast it, and tag its VLAN on the switch ports feeding them (nexus `ether2` and `ether3`). Its passphrase is the clan secret `wifi-lab` (`wifi-` and the SSID in lowercase): `clan secrets set wifi-lab`.

## When something is wrong

A typo in a name or a field is a type error from `flake/inventory/schema.nix`, naming the option and the file:

```
error: A definition for option `devices.printer.lan.vlan' is not of type `one of "guest", "iot", ...'.
error: The option `appliances.nexus.ports.ether10.cabel' does not exist.
```

A fact that spans entries fails a rule in `flake/inventory/rules.nix`, and a name in another data file fails one in `flake/inventory/references.nix`; every failing rule is listed at once:

```
error: The inventory has problems:
  - devices.printer.lan, machines.sequoia.lan: ip 10.10.0.10 is used more than once
```
