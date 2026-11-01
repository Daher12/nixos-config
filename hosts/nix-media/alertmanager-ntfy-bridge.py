import http.server
import json
import urllib.request
import os
import sys

try:
    cred_path = os.path.join(os.environ.get("CREDENTIALS_DIRECTORY", ""), "ntfy_url")
    with open(cred_path) as f:
        NTFY_URL = f.read().strip()
except Exception as e:
    print(f"Failed to load ntfy_url secret: {e}", file=sys.stderr)
    sys.exit(1)


class AlertHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length else {}
        except Exception:
            body = {}

        for alert in body.get("alerts", []):
            status = alert.get("status", "unknown")
            labels = alert.get("labels", {})
            annotations = alert.get("annotations", {})

            severity = labels.get("severity", "warning")
            alertname = labels.get("alertname", "Alert")
            summary = annotations.get("summary", "No details")

            priority = {"critical": "urgent", "warning": "high"}.get(severity, "default")

            if status == "resolved":
                tags = "white_check_mark,resolved"
                title = f"Resolved: {alertname}"
            else:
                tags = "rotating_light,warning" if severity == "warning" else "fire,critical"
                title = f"Alert: {alertname}"

            req = urllib.request.Request(NTFY_URL, data=summary.encode())
            req.add_header("Title", title)
            req.add_header("Priority", priority)
            req.add_header("Tags", tags)

            try:
                urllib.request.urlopen(req, timeout=10)
            except Exception as e:
                print(f"Failed to send to ntfy: {e}")

        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        pass


# Port from the unit (BRIDGE_PORT in monitoring.nix — single source with the
# Alertmanager webhook target).
BRIDGE_PORT = int(os.environ.get("BRIDGE_PORT", "9095"))

# ThreadingHTTPServer: one slow ntfy.sh call must not block the webhook
# listener (a burst of grouped alerts would otherwise time out Alertmanager).
server = http.server.ThreadingHTTPServer(("127.0.0.1", BRIDGE_PORT), AlertHandler)
print(f"Alertmanager-ntfy bridge listening on :{BRIDGE_PORT}")
server.serve_forever()
