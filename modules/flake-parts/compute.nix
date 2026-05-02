{ lib, ... }:
let
  raw = import ../../inventory/compute;
  clanMachines = import ../../inventory/clan/machines.nix;

  pad2 =
    value:
    let
      string = toString value;
    in
    if builtins.stringLength string == 1 then "0${string}" else string;

  duplicates =
    values:
    let
      counts = builtins.foldl' (acc: value: acc // { ${value} = (acc.${value} or 0) + 1; }) { } values;
    in
    lib.attrNames (lib.filterAttrs (_: count: count > 1) counts);

  mkInstance =
    name: instance:
    assert lib.assertMsg (
      instance ? id && builtins.isInt instance.id && instance.id > 1 && instance.id < 100
    ) "compute instance ${name}: id must be an integer from 2 to 99";
    assert lib.assertMsg (
      instance ? resources
      && instance.resources ? vcpu
      && builtins.isInt instance.resources.vcpu
      && instance.resources.vcpu > 0
    ) "compute instance ${name}: resources.vcpu must be a positive integer";
    assert lib.assertMsg (
      instance.resources ? memoryMiB
      && builtins.isInt instance.resources.memoryMiB
      && instance.resources.memoryMiB >= 256
    ) "compute instance ${name}: resources.memoryMiB must be an integer >= 256";
    let
      networkName = instance.network or "tenant";
      network =
        raw.networks.${networkName} or (throw "Unknown compute network ${networkName} for ${name}");
      bootstrap = {
        transport = "none";
        material = "none";
      }
      // (instance.bootstrap or { });
    in
    assert lib.assertMsg (builtins.elem (instance.hypervisor or "qemu") [
      "qemu"
      "cloud-hypervisor"
    ]) "compute instance ${name}: hypervisor must be one of: qemu, cloud-hypervisor";
    assert lib.assertMsg (
      !(instance ? vsockCid) || (builtins.isInt instance.vsockCid && instance.vsockCid > 2)
    ) "compute instance ${name}: vsockCid must be an integer greater than 2";
    assert lib.assertMsg (builtins.elem bootstrap.transport [
      "none"
      "seed-disk"
    ]) "compute instance ${name}: bootstrap.transport must be one of: none, seed-disk";
    assert lib.assertMsg (builtins.elem bootstrap.material [
      "none"
      "clan-machine-age-key"
    ]) "compute instance ${name}: bootstrap.material must be one of: none, clan-machine-age-key";
    assert lib.assertMsg ((bootstrap.transport == "none") == (bootstrap.material == "none"))
      "compute instance ${name}: bootstrap.transport and bootstrap.material must both be none, or both be set";
    assert lib.assertMsg (
      bootstrap.material != "clan-machine-age-key" || bootstrap.transport == "seed-disk"
    ) "compute instance ${name}: clan-machine-age-key bootstrap currently requires seed-disk transport";
    instance
    // {
      inherit name bootstrap;
      hypervisor = instance.hypervisor or "qemu";
      vsockCid = instance.vsockCid or (4000 + instance.id);
      network = networkName;
      lifecycle = {
        autostart = false;
        restartIfChanged = false;
      }
      // (instance.lifecycle or { });
      mac = instance.mac or "${network.macPrefix}:${pad2 instance.id}";
    };

  instances = lib.mapAttrs mkInstance raw.instances;

  assignmentPairs = lib.concatLists (
    lib.mapAttrsToList (host: names: map (name: { inherit host name; }) names) raw.assignments
  );
  instanceHosts = builtins.listToAttrs (
    map (pair: {
      inherit (pair) name;
      value = pair.host;
    }) assignmentPairs
  );
  assignedInstanceNames = map (pair: pair.name) assignmentPairs;
  assignmentHosts = lib.attrNames raw.assignments;

  unknownAssignmentHosts = lib.filter (host: !(builtins.hasAttr host raw.hosts)) assignmentHosts;
  unknownAssignedInstances = lib.filter (
    name: !(builtins.hasAttr name raw.instances)
  ) assignedInstanceNames;
  duplicateAssignments = duplicates assignedInstanceNames;
  instancesWithoutClanMachine = lib.filter (name: !(builtins.hasAttr name clanMachines)) (
    lib.attrNames raw.instances
  );
  instancesWithoutMachineConfig = lib.filter (
    name: !(builtins.pathExists (../../machines + "/${name}/configuration.nix"))
  ) (lib.attrNames raw.instances);
  duplicateNetworkIds = duplicates (
    lib.mapAttrsToList (_name: instance: "${instance.network}:${toString instance.id}") instances
  );
  duplicateMacs = duplicates (lib.mapAttrsToList (_name: instance: instance.mac) instances);
  duplicateVsockCids = duplicates (
    lib.mapAttrsToList (_name: instance: toString instance.vsockCid) instances
  );

  validatedInstances =
    assert lib.assertMsg (unknownAssignmentHosts == [ ])
      "compute assignments reference unknown hosts: ${lib.concatStringsSep ", " unknownAssignmentHosts}";
    assert lib.assertMsg (unknownAssignedInstances == [ ])
      "compute assignments reference unknown instances: ${lib.concatStringsSep ", " unknownAssignedInstances}";
    assert lib.assertMsg (
      duplicateAssignments == [ ]
    ) "compute instances assigned to multiple hosts: ${lib.concatStringsSep ", " duplicateAssignments}";
    assert lib.assertMsg (instancesWithoutClanMachine == [ ])
      "compute instances missing explicit Clan machines: ${lib.concatStringsSep ", " instancesWithoutClanMachine}";
    assert lib.assertMsg (instancesWithoutMachineConfig == [ ])
      "compute instances missing machines/<name>/configuration.nix: ${lib.concatStringsSep ", " instancesWithoutMachineConfig}";
    assert lib.assertMsg (duplicateNetworkIds == [ ])
      "compute instances have duplicate network/id pairs: ${lib.concatStringsSep ", " duplicateNetworkIds}";
    assert lib.assertMsg (
      duplicateMacs == [ ]
    ) "compute instances have duplicate MACs: ${lib.concatStringsSep ", " duplicateMacs}";
    assert lib.assertMsg (
      duplicateVsockCids == [ ]
    ) "compute instances have duplicate vsock CIDs: ${lib.concatStringsSep ", " duplicateVsockCids}";
    instances;

  targetFor = name: clanMachines.${name}.deploy.targetHost or "root@${name}";

  computeCommandInfo = {
    inherit (raw) assignments;
    instances = lib.mapAttrs (name: instance: {
      inherit (instance)
        id
        network
        mac
        resources
        lifecycle
        bootstrap
        hypervisor
        vsockCid
        ;
      host = instanceHosts.${name} or null;
      hostTarget = if builtins.hasAttr name instanceHosts then targetFor instanceHosts.${name} else null;
      targetHost = targetFor name;
      ip = instance.ip or null;
    }) validatedInstances;
  };
in
{
  options.flake.compute = lib.mkOption { default = { }; };

  config = {
    flake.compute = raw // {
      instances = validatedInstances;
    };

    perSystem =
      { pkgs, ... }:
      let
        computeInfo = pkgs.writeText "compute-instances.json" (builtins.toJSON computeCommandInfo);
      in
      {
        packages.compute-vm = pkgs.writeShellApplication {
          name = "compute-vm";
          runtimeInputs = [
            pkgs.gitMinimal
            pkgs.jq
            pkgs.nix
            pkgs.openssh
            pkgs.util-linux
          ];
          text = # bash
            ''
              set -euo pipefail
              # shellcheck disable=SC2016,SC2029

              data=${lib.escapeShellArg computeInfo}

              usage() {
                cat <<'EOF'
              Usage: compute-vm <command> [args]

              Commands:
                list                         List configured compute instances
                info <instance>              Print instance metadata as JSON
                status [instance]            Show systemd status for all/one instance
                start <instance>             Start microvm@<instance> on assigned host
                stop <instance>              Stop microvm@<instance> on assigned host
                restart <instance>           Restart microvm@<instance> on assigned host
                logs <instance> [lines]      Show recent host logs for the MicroVM unit
                switch <instance>            Hot-switch guest NixOS config via microvm.nix
                ssh <instance>               SSH to guest deploy target
              EOF
              }

              require_instance() {
                local name=$1
                if ! jq -e --arg name "$name" '.instances[$name]' "$data" >/dev/null; then
                  echo "Unknown compute instance: $name" >&2
                  exit 1
                fi
              }

              instance_field() {
                local name=$1
                local field=$2
                jq -r --arg name "$name" "$field" "$data"
              }

              host_target() {
                local name=$1
                local target
                target=$(instance_field "$name" ".instances[\$name].hostTarget // empty")
                if [[ -z "$target" ]]; then
                  echo "Compute instance is not assigned to a host: $name" >&2
                  exit 1
                fi
                printf '%s\n' "$target"
              }

              guest_target() {
                local name=$1
                local target
                target=$(instance_field "$name" ".instances[\$name].targetHost // empty")
                if [[ -z "$target" ]]; then
                  echo "Compute instance has no guest deploy target: $name" >&2
                  exit 1
                fi
                printf '%s\n' "$target"
              }

              repo_root() {
                git rev-parse --show-toplevel
              }

              list_instances() {
                {
                  printf 'NAME\tHOST\tTARGET\tHYPERVISOR\tVCPU\tMEMORY\tNETWORK\tMAC\n'
                  jq -r '
                    .instances
                    | to_entries[]
                    | [
                        .key,
                        (.value.host // "-"),
                        (.value.targetHost // "-"),
                        .value.hypervisor,
                        ((.value.resources.vcpu | tostring) + "vCPU"),
                        ((.value.resources.memoryMiB | tostring) + "MiB"),
                        .value.network,
                        .value.mac
                      ]
                    | @tsv
                  ' "$data"
                } | column -t -s $'\t'
              }

              status_one() {
                local name=$1
                require_instance "$name"
                local host unit
                host=$(host_target "$name")
                unit="microvm@$name.service"
                echo "== $name on $host =="
                ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" bash -s -- "$unit" <<'EOF'
              set -euo pipefail
              unit=$1
              systemctl show "$unit" -p Slice -p ActiveState -p SubState -p MemoryCurrent
              systemctl --no-pager --full status "$unit" | sed -n '1,28p'
              EOF
              }

              systemctl_instance() {
                local action=$1
                local name=$2
                require_instance "$name"
                local host
                host=$(host_target "$name")
                ssh "$host" bash -s -- "$action" "microvm@$name.service" <<'EOF'
              set -euo pipefail
              systemctl "$1" "$2"
              EOF
              }

              cmd=''${1:-}
              case "$cmd" in
                list)
                  list_instances
                  ;;
                info)
                  name=''${2:-}
                  [[ -n "$name" ]] || { usage; exit 1; }
                  require_instance "$name"
                  jq --arg name "$name" '.instances[$name]' "$data"
                  ;;
                status)
                  if [[ $# -ge 2 ]]; then
                    status_one "$2"
                  else
                    while IFS= read -r name; do
                      status_one "$name" || true
                    done < <(jq -r '.instances | keys[]' "$data")
                  fi
                  ;;
                start|stop|restart)
                  name=''${2:-}
                  [[ -n "$name" ]] || { usage; exit 1; }
                  systemctl_instance "$cmd" "$name"
                  ;;
                logs)
                  name=''${2:-}
                  lines=''${3:-80}
                  [[ -n "$name" ]] || { usage; exit 1; }
                  require_instance "$name"
                  host=$(host_target "$name")
                  ssh "$host" journalctl -u "microvm@$name.service" -n "$lines" --no-pager
                  ;;
                switch)
                  name=''${2:-}
                  [[ -n "$name" ]] || { usage; exit 1; }
                  require_instance "$name"
                  host=$(host_target "$name")
                  guest=$(guest_target "$name")
                  cd "$(repo_root)"
                  nix run ".#nixosConfigurations.$name.config.microvm.deploy.rebuild" -- "$host" "$guest"
                  ;;
                ssh)
                  name=''${2:-}
                  [[ -n "$name" ]] || { usage; exit 1; }
                  require_instance "$name"
                  guest=$(guest_target "$name")
                  if [[ $# -ne 2 ]]; then
                    echo "Usage: compute-vm ssh <instance>" >&2
                    exit 1
                  fi
                  ssh "$guest"
                  ;;
                -h|--help|help|"")
                  usage
                  ;;
                *)
                  echo "Unknown command: $cmd" >&2
                  usage
                  exit 1
                  ;;
              esac
            '';
        };
      };
  };
}
