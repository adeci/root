"""mac-install: a Mac's first nix-darwin install, from the machine that manages it."""

import argparse
import os
import sys
from collections.abc import Sequence
from typing import NoReturn

from . import Error
from .install import flake_root, install, settings


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mac-install",
        description="Install a Mac primed by the bootstrap, then walk through the System Settings steps its configuration declares. Run it from the flake's repository.",
    )
    commands = parser.add_subparsers(dest="command", required=True)

    first = commands.add_parser(
        "install",
        help="first install: host key, secrets, first switch, System Settings",
        description="""Confirm the Mac's host key, upload its secrets, copy the flake, build
and activate its configuration on the Mac, then walk through its
System Settings steps.""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""examples:
  mac-install install <machine> 192.0.2.7            with an address the bootstrap printed
  mac-install install <machine> 192.0.2.7 --dry-run  what it would do, changing nothing""",
    )
    first.add_argument("machine", help="its darwinConfigurations name")
    first.add_argument("address", help="the address the bootstrap printed")

    steps = commands.add_parser(
        "settings",
        help="walk through the System Settings steps a Mac still needs",
        description="""Walk through the System Settings steps in the Mac's /etc/mac-setup.json
whose checks still fail, such as one a later deploy added.""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""examples:
  mac-install settings <machine>            over its inventory deploy.targetHost
  mac-install settings <machine> --dry-run  which steps are done, changing nothing""",
    )
    steps.add_argument("machine", help="its darwinConfigurations name")
    steps.add_argument(
        "address",
        nargs="?",
        help="where to reach it (default: its inventory deploy.targetHost)",
    )

    dry_run = "check the Mac and show what would change, without changing anything"
    for command in (first, steps):
        command.add_argument("-n", "--dry-run", action="store_true", help=dry_run)
    return parser


def main(argv: Sequence[str] | None = None) -> NoReturn:
    args = build_parser().parse_args(argv)
    try:
        # The flake's commands refer to it as `.`.
        os.chdir(flake_root())
        if args.command == "install":
            install(args.machine, args.address, dry_run=args.dry_run)
        else:
            settings(args.machine, args.address, dry_run=args.dry_run)
    except Error as e:
        print(f"mac-install: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
    sys.exit(0)
