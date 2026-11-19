# clan-switch.py ADDRESS SYSTEM: switches janus to the system and confirms the switch with the patched clan-cli's own functions, as `clan machines update` does.
import logging
import sys
from pathlib import Path

from clan_lib.custom_logger import setup_logging
from clan_lib.errors import ClanError
from clan_lib.machines.update import _confirm_switch, _nixos_activate
from clan_lib.ssh.remote import Remote

address, system = sys.argv[1:]
setup_logging(logging.INFO)
remote = Remote(
    address=address,
    private_key=Path("/root/.ssh/id_snakeoil"),
    host_key_check="none",
)
# The switch runs over clan's own connection, which outlives it.
with remote.host_connection() as host:
    _nixos_activate(system, host, "janus")
    try:
        _confirm_switch(host, "janus", system)
    except ClanError as error:
        print(error)
        sys.exit(1)
