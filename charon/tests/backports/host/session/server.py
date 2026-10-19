#!/usr/bin/env python3
import base64
import os
import http.server
import json
import sys
import threading
import time
from urllib.parse import parse_qs, urlsplit

LAST_MODIFIED = "Wed, 21 Oct 2015 07:28:00 GMT"

lock = threading.Lock()
in_flight = {}
highest = {}
counters = {}


def content(start, end):
    return bytes((index * 7 + 3) % 256 for index in range(start, end))


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        pass

    def parameters(self):
        parts = urlsplit(self.path)
        return parts.path, {key: values[-1] for key, values in parse_qs(parts.query).items()}

    def read_body(self):
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            body = b""
            while True:
                size = int(self.rfile.readline().strip().split(b";")[0], 16)
                if size == 0:
                    while self.rfile.readline() not in (b"\r\n", b"\n", b""):
                        pass
                    return body
                body += self.rfile.read(size)
                self.rfile.readline()
        length = int(self.headers.get("Content-Length", "0") or "0")
        return self.rfile.read(length) if length else b""

    def send(self, status, body=b"", headers=(), chunked=False, chunk=0, delay=0.0, predelay=0.0):
        self.send_response(status)
        for name, value in headers:
            self.send_header(name, value)
        if chunked:
            self.send_header("Transfer-Encoding", "chunked")
        else:
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command == "HEAD":
            return
        size = chunk or max(len(body), 1)
        try:
            if predelay:
                self.wfile.flush()
                time.sleep(predelay)
            for offset in range(0, len(body), size):
                if offset and delay:
                    time.sleep(delay)
                piece = body[offset:offset + size]
                if chunked:
                    self.wfile.write(b"%x\r\n%s\r\n" % (len(piece), piece))
                else:
                    self.wfile.write(piece)
                self.wfile.flush()
            if chunked:
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True

    def handle_request(self):
        path, query = self.parameters()
        body = self.read_body() if self.command in ("POST", "PUT", "PATCH") else b""
        handler = getattr(self, "route_" + path.strip("/").replace("-", "_"), None)
        if handler is None:
            self.send(404, b"no such endpoint")
            return
        handler(query, body)

    do_GET = do_POST = do_PUT = do_HEAD = do_DELETE = do_PATCH = handle_request

    def route_bytes(self, query, body):
        total = int(query.get("n", "0"))
        headers = [("Content-Type", "application/octet-stream")]
        validator = None
        if "etag" in query:
            validator = '"%s"' % query["etag"]
            headers.append(("ETag", validator))
        if "lastmod" in query:
            validator = LAST_MODIFIED
            headers.append(("Last-Modified", LAST_MODIFIED))
        status, start = 200, 0
        requested = self.headers.get("Range", "")
        condition = self.headers.get("If-Range")
        if requested.startswith("bytes=") and validator and (condition is None or condition == validator):
            start = int(requested[6:].split("-")[0])
            status = 206
            headers.append(("Content-Range", "bytes %d-%d/%d" % (start, total - 1, total)))
        self.send(status, content(start, total), headers, chunked=query.get("chunked") == "1",
                  chunk=int(query.get("chunk", "0")), delay=int(query.get("delay", "0")) / 1000.0,
                  predelay=int(query.get("predelay", "0")) / 1000.0)

    def route_echo(self, query, body):
        report = {
            "method": self.command,
            "path": self.path,
            "headers": {name.lower(): value for name, value in self.headers.items()},
            "body": body.decode("latin-1"),
            "length": len(body),
        }
        self.send(int(query.get("code", "200")), json.dumps(report, sort_keys=True).encode(), [("Content-Type", "application/json")])

    def route_redirect(self, query, body):
        code = int(query.get("code", "302"))
        count = int(query.get("count", "1"))
        target = query.get("to", "/echo")
        if count > 1:
            target = "/redirect?code=%d&count=%d&to=%s" % (code, count - 1, target)
        elif "hostname" in query:
            target = "http://%s:%d%s" % (query["hostname"], self.server.server_address[1], target)
        self.send(code, b"redirect body", [("Location", target), ("Content-Type", "text/plain")])

    def route_status(self, query, body):
        code = int(query.get("code", "200"))
        self.send(code, b"status %d" % code, [("Content-Type", "text/plain")])

    def route_delay(self, query, body):
        time.sleep(int(query.get("ms", "1000")) / 1000.0)
        self.send(200, b"late", [("Content-Type", "text/plain")])

    def route_setcookie(self, query, body):
        cookie = "%s=%s; Path=%s" % (query.get("name", "charon"), query.get("value", "1"), query.get("path", "/"))
        self.send(200, b"set", [("Set-Cookie", cookie), ("Content-Type", "text/plain")])

    def route_auth(self, query, body):
        expected = "Basic " + base64.b64encode(("%s:%s" % (query.get("user", "user"), query.get("pass", "pass"))).encode()).decode()
        if self.headers.get("Authorization") == expected:
            self.send(200, b"authorized", [("Content-Type", "text/plain")])
        else:
            realm = query.get("realm", "charon")
            self.send(401, b"denied", [("WWW-Authenticate", 'Basic realm="%s"' % realm), ("Content-Type", "text/plain")])

    def route_concurrent(self, query, body):
        key = query.get("key", "")
        with lock:
            in_flight[key] = in_flight.get(key, 0) + 1
            highest[key] = max(highest.get(key, 0), in_flight[key])
        time.sleep(int(query.get("ms", "300")) / 1000.0)
        with lock:
            in_flight[key] -= 1
        self.send(200, b"done", [("Content-Type", "text/plain")])

    def route_highest(self, query, body):
        with lock:
            value = highest.get(query.get("key", ""), 0)
        self.send(200, str(value).encode(), [("Content-Type", "text/plain")])

    def route_counted(self, query, body):
        key = query.get("key", "")
        with lock:
            counters[key] = counters.get(key, 0) + 1
            value = counters[key]
        headers = [("Content-Type", "text/plain")]
        if "maxage" in query:
            headers.append(("Cache-Control", "max-age=%s" % query["maxage"]))
        self.send(200, b"served %d" % value, headers)

    def route_count(self, query, body):
        with lock:
            value = counters.get(query.get("key", ""), 0)
        self.send(200, str(value).encode(), [("Content-Type", "text/plain")])


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def handle_error(self, request, client_address):
        if not isinstance(sys.exc_info()[1], (BrokenPipeError, ConnectionResetError)):
            super().handle_error(request, client_address)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    server = Server((os.environ.get("CHARON_SERVER_BIND", "127.0.0.1"), port), Handler)
    print("port %d" % server.server_address[1], flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
