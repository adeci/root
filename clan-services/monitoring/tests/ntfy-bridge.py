import http.server
import json
import subprocess
import sys
import threading
import time
import urllib.request

BRIDGE_URL = "http://127.0.0.1:8000/hook"
NTFY_PORT = 8001
CLICK_URL = "https://grafana.example/d/fleet"

received = []


class FakeNtfy(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"])).decode()
        headers = {name.lower(): value for name, value in self.headers.items()}
        received.append({"path": self.path, "headers": headers, "body": body})
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        pass


def alert(fingerprint, status, severity, summary):
    return {
        "status": status,
        "labels": {"alertname": "Test", "instance": "server", "severity": severity},
        "annotations": {"summary": summary, "description": "Details."},
        "startsAt": "2026-01-01T00:00:00Z",
        "endsAt": "0001-01-01T00:00:00Z",
        "generatorURL": "",
        "fingerprint": fingerprint,
    }


def post_when_ready(payload):
    request = urllib.request.Request(
        BRIDGE_URL,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    for _ in range(100):
        try:
            with urllib.request.urlopen(request) as response:
                return response.status
        except OSError:
            time.sleep(0.1)
    raise SystemExit("alertmanager-ntfy never started listening")


def expect(fingerprint, priority, tag, title):
    message = next(candidate for candidate in received if candidate["headers"].get("x-sequence-id") == fingerprint)
    headers = message["headers"]
    problems = []
    if message["path"] != "/alerts":
        problems.append(f"posted to {message['path']}")
    if headers.get("x-priority") != priority:
        problems.append(f"priority {headers.get('x-priority')}, wanted {priority}")
    if tag not in headers.get("x-tags", "").split(","):
        problems.append(f"tags {headers.get('x-tags')}, wanted {tag}")
    if headers.get("x-title") != title:
        problems.append(f"title {headers.get('x-title')!r}, wanted {title!r}")
    if headers.get("x-click") != CLICK_URL:
        problems.append(f"click {headers.get('x-click')}")
    if message["body"] != "Details.":
        problems.append(f"body {message['body']!r}")
    return [f"{fingerprint}: {problem}" for problem in problems]


def main(config):
    ntfy = http.server.HTTPServer(("127.0.0.1", NTFY_PORT), FakeNtfy)
    threading.Thread(target=ntfy.serve_forever, daemon=True).start()

    bridge = subprocess.Popen(["alertmanager-ntfy", "--configs", config])
    try:
        status = post_when_ready(
            {
                "receiver": "ntfy",
                "status": "firing",
                "alerts": [
                    alert("critical1", "firing", "critical", "Disk is full"),
                    alert("warning1", "firing", "warning", "Disk fills up"),
                    alert("resolved1", "resolved", "critical", "Disk is full"),
                ],
            }
        )
    finally:
        bridge.terminate()
        bridge.wait()

    problems = [] if status == 200 else [f"bridge answered {status}"]
    if len(received) != 3:
        problems.append(f"ntfy got {len(received)} messages, wanted 3")
    else:
        problems += expect("critical1", "high", "rotating_light", "Disk is full")
        problems += expect("warning1", "default", "warning", "Disk fills up")
        problems += expect("resolved1", "min", "white_check_mark", "Resolved: Disk is full")

    if problems:
        sys.exit("\n".join(problems))
    print("ntfy bridge: priorities, tags, titles and sequence IDs as expected")


if __name__ == "__main__":
    main(sys.argv[1])
