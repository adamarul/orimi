"""Static file server for the web export (stdlib only).

Single-threaded web builds need no cross-origin isolation headers, so this is a plain server with
correct MIME types and caching disabled. Port 0 picks a free port; the first stdout line is
"SERVING <url>" so other scripts can read it.
"""
import argparse
import functools
import http.server
import os
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = dict(
        http.server.SimpleHTTPRequestHandler.extensions_map,
        **{".wasm": "application/wasm", ".js": "text/javascript", ".pck": "application/octet-stream"},
    )

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", required=True)
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args()
    if not os.path.isfile(os.path.join(args.dir, "index.html")):
        sys.exit("no index.html in %s (run tools/export_web.sh)" % args.dir)
    handler = functools.partial(Handler, directory=args.dir)
    server = http.server.ThreadingHTTPServer((args.host, args.port), handler)
    print("SERVING http://%s:%d/" % (args.host, server.server_address[1]), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
