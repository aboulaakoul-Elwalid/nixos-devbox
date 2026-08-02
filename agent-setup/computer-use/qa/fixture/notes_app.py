#!/usr/bin/env python3
"""A tiny notes app used as the QA harness fixture.

It exists to answer "does the harness actually work?", which needs BOTH a known
bug to find and known-healthy paths that must NOT be flagged. An oracle that has
only ever seen broken input is not known to discriminate.

THE PLANTED BUG (buggy mode, the default):
    Saving a note whose text contains an apostrophe returns HTTP 500 and the
    note is silently dropped — but the UI optimistically renders "Saved!"
    regardless of the response.

That combination is deliberate. The page LOOKS successful, so a screenshot or a
vision model sees nothing wrong. Only the network channel (a 500) or a state
re-read (the note is missing after reload) reveals it. It is the cheapest
possible reproduction of the oracle problem.

    python3 notes_app.py --port 8910           # buggy   (bug present)
    python3 notes_app.py --port 8910 --fixed   # fixed   (bug repaired)

The --fixed flag is what makes fail-before / pass-after verification possible:
the same scenario runs against both builds.
"""
import argparse
import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>Notes</title>
<style>
 body{font:15px system-ui;margin:0;padding:2rem;background:#14171f;color:#e6e9ef}
 h1{font-size:1.2rem;margin:0 0 1rem}
 input,button{font:inherit;padding:.5rem .7rem;border-radius:6px;border:1px solid #39405a}
 input{background:#1b2030;color:#e6e9ef;width:22rem}
 button{background:#3b82f6;color:#fff;border:0;cursor:pointer}
 #status{margin-left:.8rem}
 li{margin:.25rem 0}
</style></head><body>
<h1>Notes</h1>
<form id="f">
  <input id="t" name="text" placeholder="write a note" autocomplete="off" required>
  <button id="save" type="submit">Save</button>
  <span id="status"></span>
</form>
<ul id="list"></ul>
<script>
async function refresh() {
  const r = await fetch('/api/notes');
  const notes = await r.json();
  document.getElementById('list').innerHTML =
    notes.map(n => '<li data-note>' + n.replace(/[<>&]/g, c =>
      ({'<':'&lt;','>':'&gt;','&':'&amp;'}[c])) + '</li>').join('');
  document.getElementById('list').dataset.count = notes.length;
}
document.getElementById('f').addEventListener('submit', async (e) => {
  e.preventDefault();
  const text = document.getElementById('t').value;
  // NOTE: the response is deliberately ignored — optimistic UI. This is the
  // latent hazard that makes the server bug invisible on screen.
  fetch('/api/notes', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({text})
  }).catch(() => {});
  document.getElementById('status').textContent = 'Saved!';
  document.getElementById('status').dataset.state = 'saved';
  document.getElementById('t').value = '';
  setTimeout(refresh, 150);
});
refresh();
</script></body></html>
"""


class State:
    notes = []
    fixed = False
    silent_drop = False
    lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        payload = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/?"):
            return self._send(200, PAGE, "text/html; charset=utf-8")
        if self.path == "/api/notes":
            with State.lock:
                return self._send(200, json.dumps(State.notes))
        if self.path == "/api/health":
            return self._send(200, json.dumps({"ok": True, "fixed": State.fixed}))
        return self._send(404, json.dumps({"error": "not found"}))

    def do_POST(self):
        if self.path != "/api/notes":
            return self._send(404, json.dumps({"error": "not found"}))
        n = int(self.headers.get("Content-Length") or 0)
        try:
            text = json.loads(self.rfile.read(n) or b"{}").get("text", "")
        except Exception:
            return self._send(400, json.dumps({"error": "bad json"}))

        # ---- the planted bugs ------------------------------------------
        if not State.fixed and "'" in text:
            if State.silent_drop:
                # NASTIER VARIANT: claim success, store nothing. No 500, no
                # console error, no visual difference. ONLY a re-read of
                # authoritative state can catch this — it is the case that
                # proves the state-divergence signal is load-bearing rather
                # than riding along with the server-error signal.
                return self._send(201, json.dumps({"ok": True}))
            return self._send(500, json.dumps({"error": "internal error"}))
        # ----------------------------------------------------------------

        with State.lock:
            State.notes.append(text)
        return self._send(201, json.dumps({"ok": True}))

    def log_message(self, *a):
        pass  # keep the harness output clean


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8910)
    ap.add_argument("--fixed", action="store_true", help="run the repaired build")
    ap.add_argument("--silent-drop", action="store_true",
                    help="nastier bug: return 201 but store nothing (no error signal at all)")
    args = ap.parse_args()
    State.fixed = args.fixed
    State.silent_drop = args.silent_drop
    srv = HTTPServer(("127.0.0.1", args.port), Handler)
    mode = "FIXED" if args.fixed else ("BUGGY:silent-drop" if args.silent_drop else "BUGGY:500")
    print("notes fixture on http://127.0.0.1:%d (%s)" % (args.port, mode), flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
