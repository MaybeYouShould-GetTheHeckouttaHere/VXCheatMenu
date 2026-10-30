from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / '.validation/http_probe.exe'


@unittest.skipUnless(PROBE.is_file(), 'optional native probe has not been built')
class NativeTests(unittest.TestCase):
    def setUp(self):
        self.received = []
        received = self.received

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                received.append(('get', self.path))
                if self.path == '/error':
                    self.send_response(503)
                    self.end_headers()
                    return
                data = 'Inn\n広場'.encode('utf-8')
                self.send_response(200)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def do_POST(self):
                received.append(('post', self.rfile.read(int(self.headers['Content-Length']))))
                data = b'Inn\nSquare'
                self.send_response(200)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, route, post=False):
        url = f'http://127.0.0.1:{self.server.server_port}{route}'
        return subprocess.run([str(PROBE), url, '1' if post else '0'], cwd=ROOT,
                              capture_output=True, timeout=20, creationflags=0x08000000)

    def test_get_unicode_response_and_query(self):
        result = self.request('/translate?text=hello%0Aworld')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.decode('utf-8'), 'Inn\n広場')
        self.assertEqual(self.received, [('get', '/translate?text=hello%0Aworld')])

    def test_post_body(self):
        result = self.request('/', True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'Inn\nSquare')
        self.assertEqual(self.received, [('post', b'hello\nworld')])

    def test_http_failure_is_reported(self):
        self.assertEqual(self.request('/error').returncode, 4)
