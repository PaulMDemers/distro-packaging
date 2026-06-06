#!/usr/bin/env python3
"""Run a shell command in a QEMU guest through qemu-guest-agent."""

from __future__ import annotations

import argparse
import base64
import json
import socket
import sys
import time


def qga(sock: socket.socket, command: str, arguments: dict | None = None) -> dict:
    message: dict[str, object] = {"execute": command}
    if arguments is not None:
        message["arguments"] = arguments
    sock.sendall((json.dumps(message) + "\n").encode("utf-8"))

    data = b""
    while True:
        chunk = sock.recv(65536)
        if not chunk:
            raise RuntimeError("qemu-guest-agent closed the socket")
        data += chunk
        while b"\n" in data:
            line, data = data.split(b"\n", 1)
            if line.strip().startswith(b"{"):
                return json.loads(line)


def decode_field(status: dict, key: str) -> str:
    value = status.get(key)
    if not value:
        return ""
    return base64.b64decode(value).decode("utf-8", "replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", required=True, help="QGA Unix socket path")
    parser.add_argument("--timeout", type=float, default=60.0)
    parser.add_argument(
        "--command-file",
        help="Read the guest shell command from this host-side file.",
    )
    parser.add_argument("command", nargs="?", help="Shell command to run in the guest")
    args = parser.parse_args()
    if args.command_file:
        with open(args.command_file, "r", encoding="utf-8") as handle:
            command = handle.read()
    elif args.command is not None:
        command = args.command
    else:
        parser.error("provide a command or --command-file")

    deadline = time.time() + args.timeout
    while True:
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect(args.socket)
            break
        except OSError:
            if time.time() >= deadline:
                raise
            time.sleep(1)

    with sock:
        qga(sock, "guest-sync", {"id": int(time.time())})
        response = qga(
            sock,
            "guest-exec",
            {
                "path": "/bin/sh",
                "arg": ["-lc", command],
                "capture-output": True,
            },
        )
        pid = response["return"]["pid"]

        while time.time() < deadline:
            status = qga(sock, "guest-exec-status", {"pid": pid})["return"]
            if status.get("exited"):
                sys.stdout.write(decode_field(status, "out-data"))
                sys.stderr.write(decode_field(status, "err-data"))
                return int(status.get("exitcode", 0))
            time.sleep(0.5)

    print("guest command timed out", file=sys.stderr)
    return 124


if __name__ == "__main__":
    raise SystemExit(main())
