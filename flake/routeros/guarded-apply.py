"""Applies a plan with each device it changes armed to restore the configuration it had before, unless every device answers afterwards."""

import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit

import librouteros

# An armed device restores its configuration this long after arming, unless the apply has been confirmed by then.
ROLLBACK_AFTER = 5 * 60
# How long the devices that answered before the apply have to answer again, over fresh connections.
ANSWER_WITHIN = 60
TIMER = "net-apply-rollback"
BACKUP = "net-apply.backup"
MARKER = os.environ["ROLLBACK_MARKER"]
NO_ANSWER = (librouteros.exceptions.LibRouterosError, OSError)


def output(command):
    return subprocess.check_output(command, text=True)


def tofu(*arguments):
    """Runs tofu, leaving Ctrl-C to it: it finishes the changes in progress and saves the state."""
    signal.signal(signal.SIGINT, lambda *_: None)
    try:
        return subprocess.run(["tofu", *arguments]).returncode == 0
    finally:
        signal.signal(signal.SIGINT, signal.default_int_handler)


def endpoints():
    """Each device's API address, port and user, as the provider configuration that applies to it has them."""
    with open("config.tf.json") as file:
        providers = json.load(file)["provider"]["routeros"]
    devices = {}
    for provider in providers:
        url = urlsplit(provider["hosturl"])
        devices[provider["alias"]] = (url.hostname, url.port, provider["username"])
    return devices


def connect(endpoint, password):
    address, port, user = endpoint
    return librouteros.connect(host=address, port=port, username=user, password=password)


def seconds(duration):
    """A RouterOS duration such as 2w3d4h5m6s in seconds."""
    pattern = r"(?:(\d+)w)?(?:(\d+)d)?(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?"
    weeks, days, hours, minutes, secs = (int(part or 0) for part in re.fullmatch(pattern, duration).groups())
    return (((weeks * 7 + days) * 24 + hours) * 60 + minutes) * 60 + secs


def leftovers(api):
    """The rollback timer an apply leaves on a device, and its files: the saved configuration and the marker of a rollback."""
    timers = [timer[".id"] for timer in api.path("system", "scheduler") if timer["name"] == TIMER]
    files = {file["name"]: file[".id"] for file in api.path("file") if file["name"].rpartition("/")[2] in (BACKUP, MARKER)}
    return timers, files


def disarm(api):
    timers, files = leftovers(api)
    # The timer first, so it cannot fire in between.
    if timers:
        api.path("system", "scheduler").remove(*timers)
    if files:
        api.path("file").remove(*files.values())


def arm(api):
    """Saves the device's configuration and has the device restore it ROLLBACK_AFTER from now, or as soon as it restarts, until disarmed."""
    timers, files = leftovers(api)
    # An earlier marker would stop the restore at its first line, and another run's timer or backup is not this run's to replace.
    if timers or files:
        raise RuntimeError(
            f"it still has {', '.join([TIMER] * len(timers) + sorted(files))} from an earlier net-apply;"
            " run net-apply again, which reports and removes them"
        )
    # Where a device has a flash folder, files outside it are kept in memory and lost on a restart.
    folder = "flash/" if any(file["name"] == "flash" for file in api.path("file")) else ""
    armed = seconds(next(iter(api.path("system", "resource")))["uptime"])
    tuple(api("/system/backup/save", name=folder + BACKUP))
    # By uptime, as the clock jumps when NTP first synchronises; after a restart nothing can confirm the apply any more.
    restore = f"""\
:local uptime [/system resource get uptime]
:if ($uptime > {armed + ROLLBACK_AFTER}s || $uptime < {armed}s) do={{
  /file add name="{folder}{MARKER}" contents="Restored {BACKUP}, the configuration from before a net-apply that was not confirmed."
  /system backup load name="{folder}{BACKUP}" password=""
}}"""
    # Checked every 10 seconds, so the restore comes within 10 seconds of the deadline.
    api.path("system", "scheduler").add(name=TIMER, **{"start-time": "startup", "interval": "10s", "on-event": restore})


def report_leftovers(devices, password, unattended):
    """Reports and removes what earlier applies left on the devices; stops while one of them waits to roll back, and, unattended, after a rollback."""
    for name, endpoint in sorted(devices.items()):
        try:
            api = connect(endpoint, password)
        except NO_ANSWER as error:
            print(f"{name} does not answer: {error}")
            continue
        timers, files = leftovers(api)
        rolled_back = any(file.rpartition("/")[2] == MARKER for file in files)
        if timers and not rolled_back:
            sys.exit(
                f"{name} is still armed by an earlier net-apply that was not confirmed, and restores the configuration it had"
                f" before it within {ROLLBACK_AFTER // 60} minutes of that apply. Run net-apply again once it has."
            )
        # The plan would make the rolled-back changes again, so someone has to see it first.
        if rolled_back and unattended:
            sys.exit(f"{name} has rolled back an earlier net-apply, whose changes -auto-approve does not make again: run net-apply without it.")
        if timers:
            print(f"==> {name} could not restore the configuration it had before an earlier net-apply that was not confirmed,")
            print("    so it kept that apply's configuration.")
        elif rolled_back:
            print(f"==> {name} restored the configuration it had before an earlier net-apply that was not confirmed.")
            print("    Terraform's state is ahead of it, so the plan below makes that apply's changes again.")
        disarm(api)


def objects(state):
    """Each device resource in the state, by address: the device it belongs to and its RouterOS id."""
    found = {}
    for resource in state["resources"]:
        alias = resource["provider"].partition('"].')[2]
        if resource["mode"] == "managed" and alias:
            found[f"{resource['type']}.{resource['name']}"] = (alias, resource["instances"][0]["attributes"]["id"])
    return found


def changed_devices(plan, before):
    """The devices whose resources the plan changes, of those Terraform has configured before: a blank device has nothing to go back to."""
    # A resource the plan creates is not in the state yet.
    configuring = {
        resource["address"]: resource["provider_config_key"].removeprefix("routeros.")
        for resource in plan["configuration"]["root_module"]["resources"]
        if resource["provider_config_key"].startswith("routeros.")
    }
    changed = {
        before[change["address"]][0] if change["address"] in before else configuring.get(change["address"])
        for change in plan["resource_changes"]
        if change["change"]["actions"] not in (["no-op"], ["read"])
    }
    return changed & {device for device, _ in before.values()}


def answer_again(devices, names, password):
    """Fresh connections to the named devices until each has answered or ANSWER_WITHIN has passed; also returns why the others did not."""
    deadline = time.monotonic() + ANSWER_WITHIN
    connections = {}
    while True:
        errors = {}
        for name in sorted(set(names) - connections.keys()):
            try:
                connections[name] = connect(devices[name], password)
            except NO_ANSWER as error:
                errors[name] = error
        if not errors or time.monotonic() >= deadline:
            return connections, errors
        time.sleep(5)


def main():
    arguments = sys.argv[1:]
    auto_approve = "-auto-approve" in arguments
    if auto_approve:
        arguments.remove("-auto-approve")
    devices = endpoints()
    password = output(["clan", "secrets", "get", os.environ["ADMIN_SECRET"]]).rstrip("\n")

    report_leftovers(devices, password, auto_approve)

    with tempfile.TemporaryDirectory() as directory:
        plan_file = os.path.join(directory, "plan")
        if not tofu("plan", f"-out={plan_file}", *arguments):
            sys.exit(1)
        plan = json.loads(output(["tofu", "show", "-json", plan_file]))
        # A refresh-only plan changes no device, only the state.
        if "-refresh-only" in arguments:
            if not plan.get("resource_drift"):
                return
            to_arm = set()
        else:
            if all(change["change"]["actions"] in (["no-op"], ["read"]) for change in plan.get("resource_changes", [])):
                return
            before = objects(json.loads(output(["tofu", "state", "pull"])))
            to_arm = changed_devices(plan, before)
            deletions = [
                change["address"]
                for change in plan["resource_changes"]
                if "delete" in change["change"]["actions"] and change["address"] in before and before[change["address"]][0] in to_arm
            ]

        print("")
        if to_arm:
            print(f"Before applying, these save their configuration and arm a timer that restores it {ROLLBACK_AFTER // 60} minutes later,")
            print(f"unless every device that answers before the apply still answers afterwards: {', '.join(sorted(to_arm))}")
        if not auto_approve:
            try:
                answer = input("Apply? Only 'yes' will be accepted: ")
            except (EOFError, KeyboardInterrupt):
                answer = ""
            if answer != "yes":
                sys.exit("Apply cancelled.")

        if not to_arm:
            sys.exit(0 if tofu("apply", plan_file) else 1)
        answered = {}
        for name, endpoint in sorted(devices.items()):
            try:
                answered[name] = connect(endpoint, password)
            except NO_ANSWER as error:
                if name in to_arm:
                    sys.exit(f"{name} does not answer, so it cannot be armed and nothing was applied: {error}")
                print(f"{name} does not answer, so the apply does not wait for it afterwards: {error}")
        armed = []
        try:
            for name in sorted(to_arm):
                arm(answered[name])
                armed.append(name)
        except BaseException as error:
            for armed_name in armed:
                disarm(answered[armed_name])
            sys.exit(f"Arming {name} failed, so nothing was applied: {error}")
        restore_at = time.strftime("%H:%M", time.localtime(time.time() + ROLLBACK_AFTER))
        print(f"==> Armed: {', '.join(armed)}. Unless this run confirms the apply, each restores its configuration from before it and restarts at {restore_at},")
        print("    even if nothing was applied, as when this run is killed, loses its tunnel or the laptop sleeps, and at once if it restarts before then.")

        # After an interrupted apply too, the check below decides.
        applied = tofu("apply", plan_file)

    print("")
    print(f"==> Checking that every device that answered before the apply answers over a fresh connection: {', '.join(sorted(answered))}")
    try:
        answering, errors = answer_again(devices, answered, password)
    except KeyboardInterrupt:
        sys.exit(f"Interrupted, so these restore the configuration they had before this apply at {restore_at}: {', '.join(armed)}")
    restored = [name for name in armed if name in answering and not leftovers(answering[name])[0]]
    if errors or restored:
        for name, error in errors.items():
            print(f"{name} does not answer over a fresh connection: {error}")
        for name in restored:
            print(f"{name} has already restored the configuration it had before this apply.")
        print(f"==> The apply is not confirmed, so these restore the configuration they had before it at {restore_at}, and janus alerts once each has: {', '.join(armed)}")
        print("    Terraform's state is then ahead of them, and the next net-apply plans this apply's changes again.")
        after = objects(json.loads(output(["tofu", "state", "pull"])))
        # What the apply did delete comes back with the rollback but not into the state; what it never reached is still in the state.
        for address in deletions:
            if after.get(address) != before[address]:
                device, object_id = before[address]
                print(f"    {address} comes back on {device} as {object_id}, but not into the state, so adding it again fails:")
                print(f"    delete it on {device}; if the configuration still has it, the next net-apply adds it again.")
        sys.exit(1)
    undisarmed = []
    for name in armed:
        try:
            disarm(answering[name])
        except NO_ANSWER as error:
            print(f"{name} could not be disarmed: {error}")
            undisarmed.append(name)
    if undisarmed:
        sys.exit(f"==> These restore the configuration they had before this apply at {restore_at}, though it was confirmed: {', '.join(undisarmed)}")
    print(f"==> Every device answers, so the apply is confirmed and these keep it, without their timer and saved configuration: {', '.join(armed)}")
    sys.exit(0 if applied else 1)


if __name__ == "__main__":
    main()
