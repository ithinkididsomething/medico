import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

class NoCacheHTTPRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def do_GET(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) and '.' not in self.path.split('/')[-1]:
            self.path = '/index.html'
        return super().do_GET()

if __name__ == '__main__':
    web_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')
    os.chdir(web_dir)
    port = 8080
    server = HTTPServer(('0.0.0.0', port), NoCacheHTTPRequestHandler)
    print(f"Serving MEDICO web app from {web_dir} on port {port} with NO-CACHE headers...")
    sys.stdout.flush()
    server.serve_forever()
