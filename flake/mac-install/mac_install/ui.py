"""What the person running this sees, and the answers they give."""

import contextlib
import os
import select
import sys
import termios
from collections.abc import Callable, Iterator

from . import Error

TTY = "/dev/tty"


def say(text: str) -> None:
    # Flushed, so it stays in order with the output of the commands in between.
    print(text, flush=True)


def section(title: str) -> None:
    heading = f"==> {title}"
    say(f"\n\033[1m{heading}\033[0m" if sys.stdout.isatty() else f"\n{heading}")


def line(text: str) -> None:
    say(f"  {text}")


def done(text: str) -> None:
    line(f"✓ {text}")


def todo(text: str) -> None:
    line(f"→ {text}")


def warn(text: str) -> None:
    line(f"! {text}")


def detail(text: str) -> None:
    say(f"    {text}")


def would(action: str) -> None:
    """What --dry-run leaves undone."""
    detail(f"would {action}")


@contextlib.contextmanager
def terminal() -> Iterator[int]:
    """The terminal of the person running this, without what was typed before now."""
    try:
        fd = os.open(TTY, os.O_RDWR | os.O_NOCTTY)
    except OSError as e:
        msg = "this needs a terminal to answer on"
        raise Error(msg) from e
    try:
        termios.tcflush(fd, termios.TCIFLUSH)
        yield fd
    finally:
        os.close(fd)


def ask(question: str) -> bool:
    with terminal() as fd:
        os.write(fd, f"  {question} [y/N] ".encode())
        answer = os.read(fd, 1024).decode(errors="replace")
    return answer.strip().lower() in {"y", "yes"}


def wait_for_enter(prompt: str) -> None:
    with terminal() as fd:
        os.write(fd, f"    {prompt} ".encode())
        os.read(fd, 1024)


def until(condition: Callable[[], bool], *, every: float = 2) -> bool:
    """Poll `condition` until it holds; False when Enter came first."""
    with terminal() as fd:
        while not condition():
            if select.select([fd], [], [], every)[0]:
                os.read(fd, 1024)
                return False
    return True
