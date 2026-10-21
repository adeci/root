"""Hold-to-talk for Handy: keyd layer events in, SIGUSR2 toggles out.

Press starts recording; a release after --threshold-ms stops it, a shorter
tap leaves it on until the next press. Runs as root because keyd's socket is
root-only; it only reads the event stream.
"""

import argparse
import os
import signal
import subprocess
import sys
import time

# Module constants so tests can point them at a fake tree.
RUN_USER_DIR = "/run/user"
CGROUP_PROCS_FMT = (
    "/sys/fs/cgroup/user.slice"
    "/user-{uid}.slice/user@{uid}.service"
    "/app.slice/handy.service/cgroup.procs"
)
PROC_STAT_FMT = "/proc/{pid}/stat"


def handy_pids_by_uid() -> dict[int, list[int]]:
    """Main process of each logged-in user's handy.service.

    Found by cgroup, not name (the binary is `.handy-wrapped`); WebKit
    helpers share the cgroup but are children of Handy, so keep only the
    members whose parent is outside the set.
    """
    try:
        session_uids = {int(e) for e in os.listdir(RUN_USER_DIR) if e.isdigit()}
    except FileNotFoundError:
        return {}

    pids: dict[int, list[int]] = {}
    for uid in session_uids:
        try:
            with open(CGROUP_PROCS_FMT.format(uid=uid)) as f:
                members = {int(line) for line in f.read().split() if line}
        except FileNotFoundError:
            continue
        parents: dict[int, int] = {}
        for pid in members:
            try:
                with open(PROC_STAT_FMT.format(pid=pid)) as f:
                    stat = f.read()
            except (FileNotFoundError, ProcessLookupError, PermissionError):
                continue
            # ppid is the second field after comm, which may contain ')'.
            parents[pid] = int(stat[stat.rfind(")") + 1 :].split()[1])
        main = [pid for pid, ppid in parents.items() if ppid not in parents]
        if main:
            pids[uid] = main
    return pids


def toggle_all() -> None:
    for pids in handy_pids_by_uid().values():
        for pid in pids:
            try:
                os.kill(pid, signal.SIGUSR2)
            except ProcessLookupError:
                pass


def log(message: str) -> None:
    print(message, flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--layer", default="handy_ptt", help="keyd layer to watch")
    parser.add_argument(
        "--threshold-ms",
        type=int,
        default=300,
        help="hold duration that counts as push-to-talk; shorter presses lock recording on",
    )
    args = parser.parse_args()

    keyd = subprocess.Popen(["keyd", "listen"], stdout=subprocess.PIPE, stderr=sys.stderr, text=True)
    assert keyd.stdout is not None

    held = False  # a press is down and driving the recording
    locked = False  # a tap left the recording on until the next press
    pressed_at = 0.0

    try:
        for line in keyd.stdout:
            event = line.strip()
            if event == f"+{args.layer}":
                if held:
                    pass
                elif locked:
                    toggle_all()
                    locked = False
                    log("press: stop (was tap-locked)")
                else:
                    toggle_all()
                    held = True
                    pressed_at = time.monotonic()
                    log("press: start")
            elif event == f"-{args.layer}" and held:
                held = False
                held_ms = (time.monotonic() - pressed_at) * 1000
                if held_ms >= args.threshold_ms:
                    toggle_all()
                    log(f"release after {held_ms:.0f} ms: stop (push-to-talk)")
                else:
                    locked = True
                    log(f"release after {held_ms:.0f} ms: tap, recording stays on")
    except KeyboardInterrupt:
        pass
    finally:
        keyd.terminate()

    # keyd listen exiting (keyd restart, socket loss) should restart the unit.
    return keyd.wait()


if __name__ == "__main__":
    sys.exit(main())
