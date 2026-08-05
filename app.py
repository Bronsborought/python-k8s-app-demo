from http.server import BaseHTTPRequestHandler, HTTPServer


class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        message = b"Hello from my-app v1\n"

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(message)))
        self.end_headers()

        self.wfile.write(message)


server = HTTPServer(("0.0.0.0", 8000), RequestHandler)

print("Server started on port 8000")
server.serve_forever()
