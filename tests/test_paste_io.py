#!/usr/bin/env python3
import os
import signal
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PASTE = ROOT / "paste-io"


def wait_for(path, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists() and path.read_text().strip():
            return int(path.read_text().strip())
        time.sleep(0.02)
    raise SystemExit("paste child did not record its pid")


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def mock_env(tmp):
    watch = Path(tmp) / "watch"
    watch.mkdir()
    mock = Path(tmp) / "wl-paste"
    mock.write_text(
        "#!/bin/sh\n"
        "echo $$ > \"$WATCH/wl.pid\"\n"
        "sleep 30 &\n"
        "echo $! > \"$WATCH/sleep.pid\"\n"
        "wait\n"
    )
    mock.chmod(0o755)
    env = os.environ.copy()
    env["PATH"] = tmp + os.pathsep + env.get("PATH", "")
    env["WATCH"] = str(watch)
    return env, watch


def assert_dead(pid, label):
    if alive(pid):
        os.kill(pid, signal.SIGKILL)
        raise SystemExit("%s %s outlived the clipboard deadline" % (label, pid))


def main():
    if not os.access(PASTE, os.X_OK):
        raise SystemExit("paste-io is not executable")

    with tempfile.TemporaryDirectory() as tmp:
        env, watch = mock_env(tmp)
        proc = subprocess.Popen(
            [str(PASTE), "clipboard"],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        sleep_pid = wait_for(watch / "sleep.pid", 1)
        time.sleep(0.05)
        proc.send_signal(signal.SIGTERM)
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            raise SystemExit("paste-io ignored SIGTERM")
        if proc.returncode == 0:
            raise SystemExit("signalled paste-io exited 0")
        assert_dead(sleep_pid, "sleep")
        assert_dead(int((watch / "wl.pid").read_text()), "wl-paste")

    with tempfile.TemporaryDirectory() as tmp:
        env, watch = mock_env(tmp)
        started = time.monotonic()
        proc = subprocess.Popen(
            [str(PASTE), "primary"],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        sleep_pid = wait_for(watch / "sleep.pid", 1)
        try:
            proc.wait(timeout=2.5)
        except subprocess.TimeoutExpired:
            proc.kill()
            raise SystemExit("paste deadline did not stop the clipboard group")
        if time.monotonic() - started > 2.5:
            raise SystemExit("paste deadline was late")
        if proc.returncode == 0:
            raise SystemExit("timed-out paste exited 0")
        assert_dead(sleep_pid, "sleep")

    print("paste-io ok")


if __name__ == "__main__":
    main()
