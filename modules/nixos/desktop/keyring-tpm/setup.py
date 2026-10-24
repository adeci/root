"""Re-key an existing login keyring to a random password sealed in the TPM.

keyring-tpm-setup         ask for the current keyring password, re-key, seal
keyring-tpm-setup --show  print the sealed password (keep a recovery copy)
"""

import base64
import getpass
import os
import subprocess
import sys
from pathlib import Path

from gi.repository import Gio, GLib

CRED = Path.home() / ".config/keyring-tpm/password.cred"
LOGIN = "/org/freedesktop/secrets/collection/login"


def decrypt() -> str:
    return subprocess.run(
        ["systemd-creds", "decrypt", "--user", "--name=keyring-tpm", str(CRED), "-"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout


def seal(password: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["systemd-creds", "encrypt", "--user", "--name=keyring-tpm", "-", str(path)],
        check=True,
        input=password,
        text=True,
    )


def change_password(old: str, new: str) -> None:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)

    def call(interface, method, params, reply):
        return bus.call_sync(
            "org.freedesktop.secrets",
            "/org/freedesktop/secrets",
            interface,
            method,
            params,
            GLib.VariantType(reply),
            Gio.DBusCallFlags.NONE,
            -1,
            None,
        ).unpack()

    _, session = call(
        "org.freedesktop.Secret.Service",
        "OpenSession",
        GLib.Variant("(sv)", ("plain", GLib.Variant("s", ""))),
        "(vo)",
    )

    def secret(password):
        return (session, b"", password.encode(), "text/plain")

    call(
        "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface",
        "ChangeWithMasterPassword",
        GLib.Variant("(o(oayays)(oayays))", (LOGIN, secret(old), secret(new))),
        "()",
    )


def main() -> None:
    if sys.argv[1:] == ["--show"]:
        print(decrypt())
        return
    if CRED.exists():
        sys.exit(f"{CRED} already exists; nothing to do (--show prints it)")

    old = getpass.getpass("Current keyring password: ")
    new = base64.b64encode(os.urandom(32)).decode()

    staged = CRED.with_suffix(".new")
    seal(new, staged)
    try:
        change_password(old, new)
    except GLib.Error as e:
        staged.unlink()
        sys.exit(f"keyring unchanged: {e.message}")
    staged.rename(CRED)

    # Clear the start limit hit while it had no password.
    subprocess.run(["systemctl", "--user", "reset-failed", "keyring-tpm-unlock"], check=False)
    subprocess.run(["systemctl", "--user", "restart", "keyring-tpm-unlock"], check=True)
    print("Keyring re-keyed and sealed. Save a recovery copy: keyring-tpm-setup --show")


if __name__ == "__main__":
    main()
