"""Local UI audit fixture: only repository-owned public app files, never API/env files."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, unquote

APP = Path(__file__).resolve().parents[3] / 'app'

class Handler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        raw = unquote(urlsplit(path).path)
        relative = raw.removeprefix('/app/').lstrip('/')
        target = (APP / relative).resolve()
        if APP.resolve() not in target.parents and target != APP.resolve():
            return str(APP / '__denied__')
        return str(target)

    def log_message(self, *args):
        pass

if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 5177), Handler).serve_forever()
