#!/usr/bin/env python3
import os
import signal
import stat
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IO = ROOT / "board-io"
CAP = 1024 * 1024


def run(mode, path, body):
    proc = subprocess.run(
        [str(IO), mode, str(path)],
        input=body,
        capture_output=True,
    )
    return proc.returncode


def main():
    source = IO.read_text()
    if "os.O_TRUNC" in source:
        raise SystemExit("board-io still truncates a live file")

    with tempfile.TemporaryDirectory() as tmp:
        d = Path(tmp)
        board = d / "overlord.json"
        original = b'{"version":1,"cards":[]}\n'
        board.write_bytes(original)
        os.chmod(board, 0o640)
        before = board.stat().st_ino

        code = run("save", board, b'{"version":1,"cards":[{"id":"a"}]}\n')
        if code != 0:
            raise SystemExit("save failed: %s" % code)
        after = board.stat()
        if after.st_ino == before:
            raise SystemExit("save truncated the live inode instead of replacing it")
        if board.read_bytes() != b'{"version":1,"cards":[{"id":"a"}]}\n':
            raise SystemExit("save wrote the wrong body")
        if stat.S_IMODE(after.st_mode) != 0o640:
            raise SystemExit("save changed the existing mode: %o" % stat.S_IMODE(after.st_mode))
        if list(d.glob(".overlord-write-*.tmp")):
            raise SystemExit("save left a temporary file")

        marker = board.read_bytes()
        ino = board.stat().st_ino
        code = run("save", board, b"x" * (CAP + 1))
        if code != 5 or board.read_bytes() != marker or board.stat().st_ino != ino:
            raise SystemExit("oversize save changed the live board")
        if list(d.glob(".overlord-write-*.tmp")):
            raise SystemExit("oversize save left a temporary file")

        held = subprocess.Popen(
            [str(IO), "save", str(board)],
            stdin=subprocess.PIPE,
        )
        time.sleep(0.1)
        held.send_signal(signal.SIGTERM)
        held.wait(timeout=2)
        if held.returncode == 0 or board.read_bytes() != marker:
            raise SystemExit("stopped save changed the live board")

        link = d / "link.json"
        target = d / "other.json"
        target.write_bytes(b"keep\n")
        link.symlink_to(target)
        code = run("save", link, b"new\n")
        if code != 2 or target.read_bytes() != b"keep\n" or not link.is_symlink():
            raise SystemExit("symlink save was not refused")

        missing = d / "missing.json"
        code = run("save", missing, b"new\n")
        if code != 3 or missing.exists():
            raise SystemExit("save created a missing board")

        fifo = d / "pipe.json"
        os.mkfifo(fifo)
        code = run("save", fifo, b"new\n")
        if code != 4:
            raise SystemExit("pipe save was not refused: %s" % code)

        created = d / "new.json"
        code = run("create-private", created, b"fresh\n")
        if code != 0 or created.read_bytes() != b"fresh\n":
            raise SystemExit("create failed")
        if stat.S_IMODE(created.stat().st_mode) & 0o077:
            raise SystemExit("private create is group or world accessible")
        code = run("create-private", created, b"other\n")
        if code != 17 or created.read_bytes() != b"fresh\n":
            raise SystemExit("create replaced an existing board")

        outside = d / "outside"
        outside.mkdir()
        real = outside / "overlord.json"
        real.write_bytes(b"real\n")
        linked = d / "linked"
        linked.symlink_to(outside, target_is_directory=True)
        code = run("save", linked / "overlord.json", b"nope\n")
        if code != 2 or real.read_bytes() != b"real\n":
            raise SystemExit("symlink parent was followed")

    print("board-io ok")


if __name__ == "__main__":
    main()
