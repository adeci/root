"""Rotates the devices' shared admin password: the new one goes into the clan secret first, then onto each device, each confirmed over a fresh connection."""

import json
import os
import secrets
import string
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

import librouteros

SECRET = os.environ["ADMIN_SECRET"]
REFUSED = librouteros.exceptions.TrapError
FAILED = (librouteros.exceptions.LibRouterosError, OSError)


def output(command):
    return subprocess.check_output(command, text=True)


def endpoints():
    """Each device's API address, port and user, as the provider configuration that applies to it has them."""
    with open("config.tf.json") as file:
        providers = json.load(file)["provider"]["routeros"]
    devices = {}
    for provider in providers:
        url = urlsplit(provider["hosturl"])
        devices[provider["alias"]] = (url.hostname, url.port, provider["username"])
    return devices


def login(endpoint, password):
    address, port, user = endpoint
    return librouteros.connect(host=address, port=port, username=user, password=password)


def change(endpoint, api, password):
    """Sets the device's admin password and confirms it over a fresh connection."""
    user = next(row for row in api.path("user") if row["name"] == endpoint[2])
    api.path("user").update(**{".id": user[".id"], "password": password})
    login(endpoint, password)


def restore(endpoint, old, new):
    """Puts a device back on the old password, whichever of the two it has."""
    try:
        login(endpoint, old)
    except REFUSED:
        change(endpoint, login(endpoint, new), old)


def read_secret():
    # As the provider reads it, through command substitution.
    return output(["clan", "secrets", "get", SECRET]).rstrip("\n")


def store_secret(password):
    subprocess.run(["clan", "secrets", "set", SECRET], input=password, text=True, check=True, stdout=subprocess.DEVNULL)
    if read_secret() != password:
        raise RuntimeError("it reads back differently")


def previous_secret():
    """The secret before its last change: clan commits each change, and sops decrypts the older file as clan does."""
    path = f"sops/secrets/{SECRET}/secret"
    top = output(["git", "rev-parse", "--show-toplevel"]).strip()
    commits = output(["git", "-C", top, "log", "-n", "2", "--format=%H", "--", path]).split()
    if len(commits) < 2:
        return None
    with tempfile.NamedTemporaryFile("w") as file:
        file.write(output(["git", "-C", top, "show", f"{commits[1]}:{path}"]))
        file.flush()
        return output(["sops", "decrypt", file.name]).rstrip("\n")


def heal(devices, behind, current):
    """Brings devices an interrupted run left on the secret's previous value to its current one; changes nothing unless all of them can be."""
    previous = previous_secret()
    connections = {}
    for name in behind:
        try:
            connections[name] = login(devices[name], previous)
        except FAILED:
            sys.exit(f"{name}: refuses both the secret's password and the one before it, so nothing has changed")
    for name, api in connections.items():
        try:
            change(devices[name], api, current)
        except FAILED as error:
            sys.exit(f"{name}: could not be brought to the secret's password: {error}")
        print(f"{name}: brought to the secret's password")


def main():
    devices = endpoints()
    current = read_secret()

    connections, behind = {}, []
    for name, endpoint in sorted(devices.items()):
        try:
            connections[name] = login(endpoint, current)
        except REFUSED:
            behind.append(name)
        except FAILED as error:
            sys.exit(f"{name}: does not answer, so nothing has changed: {error}")
    if behind:
        heal(devices, behind, current)
        return

    new = "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32))
    try:
        store_secret(new)
    except (subprocess.CalledProcessError, RuntimeError) as error:
        store_secret(current)
        sys.exit(f"secret: the new password could not be stored, so nothing has changed: {error}")
    # From here the repository holds both: the new password as the secret, the old one in its history.
    print("secret: new password stored")

    changed = []
    for name in sorted(devices):
        try:
            change(devices[name], connections[name], new)
        except FAILED as error:
            print(f"{name}: did not take the new password: {error}")
            for other in [*changed, name]:
                restore(devices[other], current, new)
                print(f"{other}: on the old password")
            store_secret(current)
            print("secret: old password stored again")
            sys.exit(f"{name} failed, so every device and the secret are as before")
        changed.append(name)
        print(f"{name}: new password confirmed")


if __name__ == "__main__":
    main()
