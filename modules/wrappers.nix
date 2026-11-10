{
  # Options for every wrapper in wrappers/: `wrappers.<name>.enable` installs it,
  # any of its other options tweaks it for this machine, and
  # `config.wrappers.<name>.wrapper` is the built package. Built with the
  # machine's own pkgs. Features that use a wrapper import this.
  nixos =
    { self, ... }:
    {
      imports = map (wrapper: wrapper.install) (builtins.attrValues self.wrappers);
    };

  darwin =
    { self, ... }:
    {
      imports = map (wrapper: wrapper.install) (builtins.attrValues self.wrappers);
    };
}
