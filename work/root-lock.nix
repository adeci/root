# Root's inputs whose pin here differs from root's lock.
root:
let
  workLock = builtins.fromJSON (builtins.readFile ./flake.lock);
  rootLock = builtins.fromJSON (builtins.readFile (root + "/flake.lock"));

  # Lock references are node names, or `follows` paths from the lock's root; an input root added since resolves as "missing".
  resolve =
    lock: path:
    builtins.foldl' (
      node: name:
      let
        ref = node.inputs.${name} or null;
      in
      if ref == null then
        { locked.rev = "missing"; }
      else if builtins.isList ref then
        resolve lock ref
      else
        lock.nodes.${ref}
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
