from http.server import BaseHTTPRequestHandler, HTTPServer
import os


class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        pod_name = os.getenv("HOSTNAME", "unknown")
        app_message = os.getenv("APP_MESSAGE", "Hello")
        app_secret = os.getenv("APP_SECRET", "")

        if self.path == "/secret":
            provided_secret = self.headers.get("X-API-Key", "")

            if provided_secret != app_secret:
                message = "Unauthorized\n".encode()
                self.send_response(401)
            else:
                message = "Secret access granted\n".encode()
                self.send_response(200)

        else:
            message = f"{app_message} | Pod: {pod_name}\n".encode()
            self.send_response(200)

        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(message)))
        self.end_headers()

        self.wfile.write(message)


server = HTTPServer(("0.0.0.0", 8000), RequestHandler)

print("Server started on port 8000")
server.serve_forever()
