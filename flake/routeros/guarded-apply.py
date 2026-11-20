"""Apply a plan; each changed device rolls back unless every device answers afterwards."""

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

# Armed devices restore their config this long after arming unless confirmed.
ROLLBACK_AFTER = 5 * 60
# How long devices that answered before the apply get to answer again.
ANSWER_WITHIN = 60
TIMER = "net-apply-rollback"
BACKUP = "net-apply.backup"
MARKER = os.environ["ROLLBACK_MARKER"]
NO_ANSWER = (librouteros.exceptions.LibRouterosError, OSError)


def output(command):
    return subprocess.check_output(command, text=True)


def tofu(*arguments):
    """Run tofu and leave Ctrl-C to it, so it finishes in-flight changes and saves state."""
    signal.signal(signal.SIGINT, lambda *_: None)
    try:
        return subprocess.run(["tofu", *arguments]).returncode == 0
    finally:
        signal.signal(signal.SIGINT, signal.default_int_handler)


def endpoints():
    """Each device's API address, port and user, from its provider config."""
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
    """The rollback timer and files (backup, rollback marker) an apply leaves on a device."""
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
    """Save the config and restore it ROLLBACK_AFTER from now, or on restart, until disarmed."""
    timers, files = leftovers(api)
    # A stale marker stops the restore at line one; another run's timer or backup isn't ours.
    if timers or files:
        raise RuntimeError(
            f"it still has {', '.join([TIMER] * len(timers) + sorted(files))} from an earlier net-apply;"
            " run net-apply again to report and remove them"
        )
    # With a flash folder, files outside it live in RAM and are lost on restart.
    folder = "flash/" if any(file["name"] == "flash" for file in api.path("file")) else ""
    armed = seconds(next(iter(api.path("system", "resource")))["uptime"])
    tuple(api("/system/backup/save", name=folder + BACKUP))
    # By uptime: the clock jumps at first NTP sync, and after a restart nothing can confirm.
    restore = f"""\
:local uptime [/system resource get uptime]
:if ($uptime > {armed + ROLLBACK_AFTER}s || $uptime < {armed}s) do={{
  /file add name="{folder}{MARKER}" contents="Restored {BACKUP}: config from before an unconfirmed net-apply."
  /system backup load name="{folder}{BACKUP}" password=""
}}"""
    # Checked every 10 s, so the restore lands within 10 s of the deadline.
    api.path("system", "scheduler").add(name=TIMER, **{"start-time": "startup", "interval": "10s", "on-event": restore})


def report_leftovers(devices, password, unattended):
    """Report and remove what earlier applies left; stop if one is still armed, or unattended after a rollback."""
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
                f"{name} is still armed by an earlier unconfirmed net-apply and restores its prior config"
                f" within {ROLLBACK_AFTER // 60} minutes of it. Run net-apply again once it has."
            )
        # The plan would redo the rolled-back changes, so someone has to see it first.
        if rolled_back and unattended:
            sys.exit(f"{name} rolled back an earlier net-apply; -auto-approve won't redo its changes: run net-apply without it.")
        if timers:
            print(f"==> {name} couldn't restore its config from before an earlier unconfirmed net-apply,")
            print("    so it kept that apply's config.")
        elif rolled_back:
            print(f"==> {name} restored its config from before an earlier unconfirmed net-apply.")
            print("    Terraform's state is ahead of it, so the plan below redoes that apply's changes.")
        disarm(api)


def objects(state):
    """Each device resource in the state, by address: (device, RouterOS id)."""
    found = {}
    for resource in state["resources"]:
        alias = resource["provider"].partition('"].')[2]
        if resource["mode"] == "managed" and alias:
            found[f"{resource['type']}.{resource['name']}"] = (alias, resource["instances"][0]["attributes"]["id"])
    return found


def changed_devices(plan, before):
    """Devices whose resources the plan changes, among those already configured: a blank one has nothing to go back to."""
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
    """Reconnect to the named devices until each answers or ANSWER_WITHIN passes; also return why the others didn't."""
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
            print(f"Before applying, these save their config and arm a timer to restore it {ROLLBACK_AFTER // 60} minutes later,")
            print(f"unless every device that answered before still answers after: {', '.join(sorted(to_arm))}")
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
                    sys.exit(f"{name} does not answer, so it can't be armed; nothing applied: {error}")
                print(f"{name} does not answer; not waiting for it afterwards: {error}")
        armed = []
        try:
            for name in sorted(to_arm):
                arm(answered[name])
                armed.append(name)
        except BaseException as error:
            for armed_name in armed:
                disarm(answered[armed_name])
            sys.exit(f"Arming {name} failed; nothing applied: {error}")
        restore_at = time.strftime("%H:%M", time.localtime(time.time() + ROLLBACK_AFTER))
        print(f"==> Armed: {', '.join(armed)}. Unless this run confirms, each restores its prior config and restarts at {restore_at},")
        print("    even if nothing applied (run killed, tunnel lost, laptop asleep), and at once if it restarts sooner.")

        # Even after an interrupted apply, the check below decides.
        applied = tofu("apply", plan_file)

    print("")
    print(f"==> Checking every device that answered before answers over a fresh connection: {', '.join(sorted(answered))}")
    try:
        answering, errors = answer_again(devices, answered, password)
    except KeyboardInterrupt:
        sys.exit(f"Interrupted; these restore their pre-apply config at {restore_at}: {', '.join(armed)}")
    restored = [name for name in armed if name in answering and not leftovers(answering[name])[0]]
    if errors or restored:
        for name, error in errors.items():
            print(f"{name} does not answer over a fresh connection: {error}")
        for name in restored:
            print(f"{name} has already restored its pre-apply config.")
        print(f"==> Apply not confirmed: these restore their pre-apply config at {restore_at}, and janus alerts once each has: {', '.join(armed)}")
        print("    Terraform's state is then ahead of them; the next net-apply plans this apply's changes again.")
        after = objects(json.loads(output(["tofu", "state", "pull"])))
        # Deletes come back with the rollback but not into the state; unreached ones stay in it.
        for address in deletions:
            if after.get(address) != before[address]:
                device, object_id = before[address]
                print(f"    {address} comes back on {device} as {object_id} but not into the state, so re-adding it fails:")
                print(f"    delete it on {device}; if the config still has it, the next net-apply adds it again.")
        sys.exit(1)
    undisarmed = []
    for name in armed:
        try:
            disarm(answering[name])
        except NO_ANSWER as error:
            print(f"{name} could not be disarmed: {error}")
            undisarmed.append(name)
    if undisarmed:
        sys.exit(f"==> These restore their pre-apply config at {restore_at} even though it was confirmed: {', '.join(undisarmed)}")
    print(f"==> Every device answers: apply confirmed, timers and backups removed: {', '.join(armed)}")
    sys.exit(0 if applied else 1)


if __name__ == "__main__":
    main()
