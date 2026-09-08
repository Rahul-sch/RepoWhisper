"""Exercise the packaged sidecar in a temporary, isolated data directory."""
import json
import os
from pathlib import Path
import secrets
import socket
import stat
import subprocess
import sys
import tempfile
import time


def request(path, token=None, body=None):
    headers = [f"{'POST' if body else 'GET'} {path} HTTP/1.1", "Host: localhost", "Connection: close"]
    if token:
        headers.append(f"X-Auth-Token: {token}")
    if body:
        headers.extend(["Content-Type: application/json", f"Content-Length: {len(body)}"])
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(10)
        client.connect(socket_path)
        client.sendall(("\r\n".join(headers) + "\r\n\r\n").encode() + (body or b""))
        response = bytearray()
        while chunk := client.recv(4096):
            response.extend(chunk)
    return bytes(response)


if __name__ == "__main__":
    executable = str(Path(sys.argv[1]).resolve(strict=True))
    with tempfile.TemporaryDirectory(prefix="rw-sec-", dir="/tmp") as temporary:
        root = Path(temporary)
        allowlist = root / "allowlist.json"
        allowlist.write_text(json.dumps([str(root)]))
        socket_path = str(root / "backend.sock")
        token = secrets.token_hex(32)
        env = {**os.environ, "REPOWHISPER_ALLOWLIST_FILE": str(allowlist),
               "REPOWHISPER_SOCKET_PATH": socket_path, "REPOWHISPER_AUTH_TOKEN": token,
               "REPOWHISPER_DATA_DIR": str(root / "data"), "DEBUG": "false"}
        with (root / "backend.log").open("w+") as log:
            process = subprocess.Popen([executable], cwd=root, env=env, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 120
                while not Path(socket_path).exists():
                    if process.poll() is not None or time.monotonic() > deadline:
                        log.seek(0)
                        raise RuntimeError("Frozen startup failed: " + log.read()[-4000:])
                    time.sleep(0.5)
                assert stat.S_IMODE(Path(socket_path).stat().st_mode) == 0o600
                assert b" 200 " in request("/health").split(b"\r\n", 1)[0]
                assert b" 401 " in request("/repos").split(b"\r\n", 1)[0]
                body = json.dumps({"query": "PRIVATE-SOURCE" * 100}).encode()
                result = request("/search", token, body)
                assert b" 422 " in result.split(b"\r\n", 1)[0]
                assert b"PRIVATE-SOURCE" not in result
                print("Frozen health, token enforcement, sanitized validation, and socket mode passed.")
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
