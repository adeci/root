# Inherited inputs are pinned in this lock, not root's; list each that drifts so eval fails instead of building stale.
root:
let
  workLock = builtins.fromJSON (builtins.readFile ./flake.lock);
  rootLock = builtins.fromJSON (builtins.readFile (root + "/flake.lock"));

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
