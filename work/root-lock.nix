# Inputs this flake inherits through `root` are pinned in work/flake.lock, not
# in root's lock. Return a message for each inherited input whose pin differs
# from root's flake.lock, so evaluation can fail instead of silently building
# stale inputs. `nix flake update root` (from work/) re-syncs all of them.
root:
let
  workLock = builtins.fromJSON (builtins.readFile ./flake.lock);
  rootLock = builtins.fromJSON (builtins.readFile (root + "/flake.lock"));

  # Follow an input path such as [ "root" "pi-kit" ] from a lock's root node.
  # Lock references are node names, or `follows` paths from the lock's root.
  resolve =
    lock: path:
    builtins.foldl' (
      node: name:
      let
        ref = node.inputs.${name};
      in
      if builtins.isList ref then resolve lock ref else lock.nodes.${ref}
    ) lock.nodes.${lock.root} path;

  pin = node: node.locked.narHash or (builtins.toJSON (node.locked or { }));
  short = node: builtins.substring 0 7 (node.locked.rev or (pin node));

  inherited = builtins.attrNames (rootLock.nodes.${rootLock.root}.inputs or { });
  stale = builtins.filter (
    name:
    pin (
      resolve workLock [
        "root"
        name
      ]
    ) != pin (resolve rootLock [ name ])
  ) inherited;
in
map (
  name:
  "${name}: ${
    short (
      resolve workLock [
        "root"
        name
      ]
    )
  } (work) != ${short (resolve rootLock [ name ])} (root)"
) stale
