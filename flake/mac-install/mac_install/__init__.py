"""Install nix-darwin on a Mac primed by bootstrap.sh, then walk through the System Settings steps its configuration declares."""


class Error(Exception):
    """A failure the person running this can act on, shown without a traceback."""
