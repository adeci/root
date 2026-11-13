"""ui against a pseudo-terminal."""

import os
import pty
import select
import threading
from collections.abc import Iterator
from dataclasses import dataclass

import pytest

from mac_install import Error, ui


@dataclass
class Keyboard:
    fd: int
    screen: int

    def type(self, keys: bytes) -> None:
        """Type ahead, and wait until the keys reach the terminal."""
        os.write(self.fd, keys)
        select.select([self.screen], [], [], 5)

    def answer(self, prompt: bytes, keys: bytes) -> threading.Thread:
        """Type `keys` once `prompt` shows, like a person reading the screen."""

        def person() -> None:
            shown = b""
            while prompt not in shown and select.select([self.fd], [], [], 5)[0]:
                shown += os.read(self.fd, 1024)
            os.write(self.fd, keys)

        thread = threading.Thread(target=person)
        thread.start()
        return thread


@pytest.fixture
def keyboard(monkeypatch: pytest.MonkeyPatch) -> Iterator[Keyboard]:
    try:
        fd, screen = pty.openpty()
    except OSError:
        pytest.skip("no pseudo-terminals here")
    monkeypatch.setattr(ui, "TTY", os.ttyname(screen))
    yield Keyboard(fd, screen)
    os.close(fd)
    os.close(screen)


@pytest.mark.parametrize(
    ("keys", "answer"),
    [(b"y\n", True), (b"Yes\n", True), (b"\n", False), (b"n\n", False)],
)
def test_ask_takes_only_yes(keyboard: Keyboard, keys: bytes, answer: bool) -> None:
    person = keyboard.answer(b"[y/N] ", keys)
    assert ui.ask("Same as the one the Mac printed?") is answer
    person.join()


def test_keys_pressed_before_a_question_do_not_answer_it(keyboard: Keyboard) -> None:
    keyboard.type(b"y\n")
    person = keyboard.answer(b"[y/N] ", b"n\n")
    assert ui.ask("Same as the one the Mac printed?") is False
    person.join()


def test_until_polls_until_the_condition_holds(keyboard: Keyboard) -> None:
    # Enter pressed before the wait began is not a skip.
    keyboard.type(b"\n")
    polls = iter([False, False, True])
    assert ui.until(lambda: next(polls), every=0.01) is True


def test_enter_ends_the_wait(keyboard: Keyboard) -> None:
    polls = 0

    def check() -> bool:
        nonlocal polls
        polls += 1
        if polls == 3:
            os.write(keyboard.fd, b"\n")
        # Holds long after Enter, so a wait Enter doesn't end still ends.
        return polls > 100

    assert ui.until(check, every=0.01) is False
    assert polls >= 3


def test_no_terminal_fails_plainly(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(ui, "TTY", "/nonexistent/tty")
    with pytest.raises(Error, match="needs a terminal"):
        ui.ask("Same as the one the Mac printed?")
