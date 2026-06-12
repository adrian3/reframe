#!/usr/bin/env python3

"""Tiny local reverse proxy for the reFrame dashboard.

Runs on port 80 and forwards requests to dashboard.py on 127.0.0.1:8000.
This keeps the dashboard service unprivileged while giving phones a clean
http://hostname.local URL.
"""

from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os


TARGET_HOST = os.environ.get("REFRAME_DASHBOARD_HOST", "127.0.0.1")
TARGET_PORT = int(os.environ.get("REFRAME_DASHBOARD_PORT", "8000"))
LISTEN_HOST = os.environ.get("REFRAME_PROXY_HOST", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("REFRAME_PROXY_PORT", "80"))


class DashboardProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self._proxy()

    def do_POST(self):
        self._proxy()

    def do_PUT(self):
        self._proxy()

    def do_DELETE(self):
        self._proxy()

    def do_OPTIONS(self):
        self._proxy()

    def do_HEAD(self):
        self._proxy(method_override="GET", send_body=False)

    def _proxy(self, method_override=None, send_body=True):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0") or "0"))
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in {"host", "connection", "keep-alive", "proxy-connection", "transfer-encoding"}
        }
        headers["Host"] = f"{TARGET_HOST}:{TARGET_PORT}"
        headers["X-Forwarded-Host"] = self.headers.get("Host", "")
        headers["X-Forwarded-Proto"] = "http"

        conn = None
        try:
            conn = HTTPConnection(TARGET_HOST, TARGET_PORT, timeout=30)
            conn.request(method_override or self.command, self.path, body=body, headers=headers)
            response = conn.getresponse()
            response_body = response.read()

            self.send_response(response.status, response.reason)
            for key, value in response.getheaders():
                if key.lower() in {"connection", "content-length", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade"}:
                    continue
                self.send_header(key, value)
            self.send_header("Content-Length", str(len(response_body)))
            self.end_headers()
            if send_body:
                self.wfile.write(response_body)
        except Exception as e:
            message = f"Dashboard proxy error: {e}".encode("utf-8")
            self.send_response(502)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(message)))
            self.end_headers()
            self.wfile.write(message)
        finally:
            try:
                conn.close()
            except Exception:
                pass

    def log_message(self, fmt, *args):
        print("%s - - [%s] %s" % (self.address_string(), self.log_date_time_string(), fmt % args), flush=True)


if __name__ == "__main__":
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), DashboardProxyHandler)
    print(f"reFrame dashboard proxy listening on {LISTEN_HOST}:{LISTEN_PORT} -> {TARGET_HOST}:{TARGET_PORT}", flush=True)
    server.serve_forever()
